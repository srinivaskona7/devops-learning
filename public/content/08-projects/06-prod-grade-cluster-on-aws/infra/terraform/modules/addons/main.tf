###############################################################################
# Module: addons
# Installs all cluster addons via Helm:
#   - AWS Load Balancer Controller (ALB ingress)
#   - cert-manager (TLS certificate management)
#   - external-dns (Route53 DNS record management)
#   - metrics-server (HPA/VPA resource metrics)
#   - EBS CSI Driver (persistent volumes)
###############################################################################

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: IRSA trust policy document factory
# ─────────────────────────────────────────────────────────────────────────────
locals {
  oidc_sub_prefix = "${var.oidc_provider_url}:sub"
  oidc_aud_prefix = "${var.oidc_provider_url}:aud"
}

# ─────────────────────────────────────────────────────────────────────────────
# AWS Load Balancer Controller
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "alb_controller" {
  name = "${var.cluster_name}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub_prefix}" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${local.oidc_aud_prefix}" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

# Full ALB controller policy (sourced from AWS docs)
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller"
  description = "AWS Load Balancer Controller policy for ${var.cluster_name}"

  policy = file("${path.module}/policies/alb-controller-policy.json")
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_version
  wait       = true
  timeout    = 300

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
  set {
    name  = "replicaCount"
    value = "2"
  }
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# cert-manager
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "cert_manager" {
  name = "${var.cluster_name}-cert-manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub_prefix}" = "system:serviceaccount:cert-manager:cert-manager"
          "${local.oidc_aud_prefix}" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "cert_manager" {
  name        = "${var.cluster_name}-cert-manager"
  description = "cert-manager Route53 DNS-01 challenge permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:GetChange"]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
        ]
        Resource = var.route53_zone_id != "" ? "arn:aws:route53:::hostedzone/${var.route53_zone_id}" : "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZonesByName"]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  role       = aws_iam_role.cert_manager.name
  policy_arn = aws_iam_policy.cert_manager.arn
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cert_manager.arn
  }
  set {
    name  = "securityContext.fsGroup"
    value = "1001"
  }
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# external-dns
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "external_dns" {
  name = "${var.cluster_name}-external-dns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub_prefix}" = "system:serviceaccount:external-dns:external-dns"
          "${local.oidc_aud_prefix}" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "external_dns" {
  name = "${var.cluster_name}-external-dns"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
        ]
        Resource = ["*"]
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  namespace        = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.external_dns_version
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [yamlencode({
    provider = "aws"
    aws = {
      region = var.aws_region
    }
    domainFilters = var.external_dns_domain != "" ? [var.external_dns_domain] : []
    policy        = "upsert-only"  # safe default — never deletes records
    txtOwnerId    = var.cluster_name
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
      }
    }
    tolerations = [{
      key      = "CriticalAddonsOnly"
      operator = "Exists"
      effect   = "NoSchedule"
    }]
  })]
}

# ─────────────────────────────────────────────────────────────────────────────
# metrics-server
# ─────────────────────────────────────────────────────────────────────────────
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version
  wait       = true
  timeout    = 180

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EBS CSI Driver
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub_prefix}" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_aud_prefix}" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = var.ebs_csi_driver_version
  wait       = true
  timeout    = 300

  values = [yamlencode({
    controller = {
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi.arn
        }
      }
      tolerations = [{
        key      = "CriticalAddonsOnly"
        operator = "Exists"
        effect   = "NoSchedule"
      }]
    }
    node = {
      tolerateAllTaints = true
    }
    storageClasses = [{
      name = "ebs-gp3-enc"
      annotations = {
        "storageclass.kubernetes.io/is-default-class" = "true"
      }
      provisioner          = "ebs.csi.aws.com"
      volumeBindingMode    = "WaitForFirstConsumer"
      reclaimPolicy        = "Retain"
      allowVolumeExpansion = true
      parameters = {
        type      = "gp3"
        encrypted = "true"
        throughput = "125"
        iops       = "3000"
      }
    }]
  })]
}
