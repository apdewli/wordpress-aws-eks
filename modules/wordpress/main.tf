resource "kubernetes_namespace" "wordpress" {
  metadata {
    name = "wordpress"
  }
}

resource "helm_release" "wordpress" {
  name       = "wordpress"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "wordpress"
  namespace  = kubernetes_namespace.wordpress.metadata[0].name
  version    = "15.4.1"
  
  set {
    name  = "image.registry"
    value = split("/", var.ecr_repo_url)[0]
  }
  
  set {
    name  = "image.repository"
    value = split("/", var.ecr_repo_url)[1]
  }
  
  set {
    name  = "image.tag"
    value = "latest"
  }
  
  set {
    name  = "externalDatabase.host"
    value = split(":", var.rds_endpoint)[0]
  }
  
  set {
    name  = "externalDatabase.user"
    value = "admin"
  }
  
  set {
    name  = "externalDatabase.password"
    value = "changeme123!"
  }
  
  set {
    name  = "externalDatabase.database"
    value = "wordpress"
  }
  
  set {
    name  = "mariadb.enabled"
    value = "false"
  }
  
  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  
  set {
    name  = "ingress.enabled"
    value = "true"
  }
  
  set {
    name  = "ingress.ingressClassName"
    value = "alb"
  }
  
  set {
    name  = "ingress.annotations.alb\.ingress\.kubernetes\.io/scheme"
    value = "internet-facing"
  }
  
  set {
    name  = "ingress.annotations.alb\.ingress\.kubernetes\.io/target-type"
    value = "ip"
  }
}