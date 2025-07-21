variable "aws_region" {
  description = "EC2 인스턴스 리전"
  type = string
  default = "ap-northeast-2"
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type = string
  default = "t2.micro"
}

variable "mongodb_admin_user" {
  description = "MongoDB 관리자 사용자 이름"
  type        = string
  sensitive   = true
}

variable "mongodb_admin_password" {
  description = "MongoDB 관리자 비밀번호"
  type        = string
  sensitive   = true
}
