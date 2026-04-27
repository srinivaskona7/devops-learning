###############################################################################
# Module: karpenter
# Installs Karpenter controller via Helm + creates NodePool + EC2NodeClass
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── IRSA role for Karpenter controller ───────────────────────────────────────
data "aws_iam_policy_document" "karpenter_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "${var.cluster_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_assume.json
  tags               = var.tags
}

# Karpenter controller permissions (principle of least privilege)
resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.cluster_name}-karpenter-controller"
  description = "Karpenter controller permissions for cluster ${var.cluster_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceActions"
        Effect = "Allow"
        Resource = [
          "arn:aws:ec2:*::image/*",
          "arn:aws:ec2:*::snapshot/*",
          "arn:aws:ec2:*:*:spot-instances-request/*",
          "arn:aws:ec2:*:*:security-group/*",
          "arn:aws:ec2:*:*:subnet/*",
          "arn:aws:ec2:*:*:key-pair/*",
          "arn:aws:ec2:*:*:launch-template/*",
          "arn:aws:ec2:*:*:network-interface/*",
          "arn:aws:ec2:*:*:instance/*",
        ]
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
        ]
      },
      {
        Sid      = "AllowScopedEC2InstanceActionsWithTags"
        Effect   = "Allow"
        Resource = ["arn:aws:ec2:*:*:instance/*", "arn:aws:ec2:*:*:launch-template/*"]
        Action   = ["ec2:TerminateInstances", "ec2:DeleteLaunchTemplate"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/karpenter.sh/nodepool" : "*"
          }
        }
      },
      {
        Sid      = "AllowInstanceProfileActions"
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts",
          "eks:DescribeCluster",
          "iam:GetInstanceProfile",
          "iam:PassRole",
        ]
      },
      {
        Sid      = "AllowSQSActions"
        Effect   = "Allow"
        Resource = aws_sqs_queue.karpenter_interruption.arn
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ── Spot interruption handling via SQS + EventBridge ─────────────────────────
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# EventBridge rules — capture EC2 interruption signals
resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.cluster_name}-spot-interruption"
  description = "Spot instance interruption warning for Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "instance_rebalance" {
  name        = "${var.cluster_name}-instance-rebalance"
  description = "EC2 instance rebalance recommendation for Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "instance_rebalance" {
  rule = aws_cloudwatch_event_rule.instance_rebalance.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# ── Instance profile for Karpenter-launched nodes ────────────────────────────
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "KarpenterNodeInstanceProfile-${var.cluster_name}"
  role = var.node_iam_role_name
  tags = var.tags
}

# ── Karpenter Helm release ─────────────────────────────────────────────────────
resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [yamlencode({
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller.arn
      }
    }
    settings = {
      clusterName       = var.cluster_name
      clusterEndpoint   = var.cluster_endpoint
      interruptionQueue = aws_sqs_queue.karpenter_interruption.name
    }
    controller = {
      resources = {
        requests = { cpu = "250m", memory = "256Mi" }
        limits   = { cpu = "1", memory = "1Gi" }
      }
    }
    tolerations = [{
      key      = "CriticalAddonsOnly"
      operator = "Exists"
      effect   = "NoSchedule"
    }]
    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [{
              key      = "node.kubernetes.io/node-type"
              operator = "In"
              values   = ["managed"]
            }]
          }]
        }
      }
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [{
          weight = 100
          podAffinityTerm = {
            topologyKey = "kubernetes.io/hostname"
            labelSelector = {
              matchLabels = { "app.kubernetes.io/name" = "karpenter" }
            }
          }
        }]
      }
    }
  })]
}

# ── EC2NodeClass ───────────────────────────────────────────────────────────────
resource "kubernetes_manifest" "ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = var.ami_family
      role      = var.node_iam_role_name

      subnetSelectorTerms = [
        for subnet_id in var.private_subnet_ids : {
          id = subnet_id
        }
      ]

      securityGroupSelectorTerms = [{
        tags = {
          "karpenter.sh/discovery" = var.cluster_name
        }
      }]

      tags = merge(var.tags, {
        "karpenter.sh/discovery" = var.cluster_name
      })

      blockDeviceMappings = [{
        deviceName = "/dev/xvda"
        ebs = {
          volumeSize          = "50Gi"
          volumeType          = "gp3"
          iops                = 3000
          throughput          = 125
          encrypted           = true
          deleteOnTermination = true
        }
      }]

      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 1       # block SSRF
        httpTokens              = "required"  # IMDSv2 only
      }
    }
  }

  depends_on = [helm_release.karpenter]
}

# ── NodePool ───────────────────────────────────────────────────────────────────
resource "kubernetes_manifest" "node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "node.kubernetes.io/node-type" = "karpenter"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = var.instance_types
            },
            {
              key      = "topology.kubernetes.io/zone"
              operator = "In"
              values   = var.availability_zones
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
          ]
          # Karpenter-managed nodes expire after 720h → rolling AMI updates
          expireAfter = "720h"
        }
      }
      disruption = {
        consolidationPolicy = "WhenUnderutilized"
        consolidateAfter    = "30s"
      }
      limits = {
        cpu    = var.nodepool_cpu_limit
        memory = var.nodepool_memory_limit
      }
    }
  }

  depends_on = [
    kubernetes_manifest.ec2_node_class,
    helm_release.karpenter,
  ]
}
