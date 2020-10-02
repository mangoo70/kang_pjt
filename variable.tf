# variable.tf 파일의 변수 명 확인해주세요!!!! 이 라인부터 '#' 으로 막아주세요!
variable.tf 파일의 변수 명 확인해주세요!!!! 이 라인부터 '#' 으로 막아주세요!

variable "userid" {
    # 할당 받은 user ID 입력
    default = "user11"
}

variable "region" {
    # 할당 받은 리전 ID 입력
    default = "eu-west-1"
}

variable "az1" {
    # VPC 서비스 → 서브넷 → 서브넷 생성 버튼을 누르고 가용 영역 중 하나 입력
    default = "eu-west-1a"
}

variable "az2" {
    # VPC 서비스 → 서브넷 → 서브넷 생성 버튼을 누르고 가용 영역 중 하나 입력
    default = "eu-west-1b"
}

variable "vpc1-cidr" {
    # 할당받은 VPC CIDR 입력(X.0.0.0/16)
    default = "11.0.0.0/16"
}

variable "subnet1-cidr" {
    # 할당받은 VPC CIDR 내 서브넷 입력(X.0.1.0/24)
    default = "11.0.1.0/24"
}

variable "subnet2-cidr" {
    # 할당받은 VPC CIDR 내 서브넷 입력(X.0.2.0/24)
    default = "11.0.2.0/24"
}

variable "ami-id" {
    # EC2 서비스 → 인스턴스 → 인스턴스 시작 버튼을 누르고 Amazon Linux AMI 2018.03.0 (HVM), SSD Volume Type 의 AMI ID 입력
    # 절대 Amazon Linux 2의 AMI ID 입력하지 말것! 반드시 2018.03.0 버전을 보고 AMI ID 입력
    default = "ami-0a7c31280fbd23a86"
}

variable "alb-account-id" {
    # 문서에서 해당 리전의 ALB Account ID 선택해서 입력
    default = "156460612806"
}

variable "cloud9-cidr" {
    # Cloud9의 공인 IP를 확인하여 입력(X.X.X.X/32)
    # Cloud9을 생성한 리전에서 해당 Cloud9 인스턴스를 찾아 상세 정보에서 퍼블릭 IPv4 주소 항목 확인
    default = "13.124.126.144/32"
}