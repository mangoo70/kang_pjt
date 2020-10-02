# final_pjt
최종 테스트용

[사전 환경 설정]
- Cloud9 IDE 생성
Cloud9 서비스 → Create Environment 클릭하여 IDE 생성
- Cloud9 temporary credentials 해제
Cloud9 → 기어모양(Preferences) → AWS Settings → AWS managed temporary credentials 체크 해제

- Access Key 생성 및 PATH 등록
IAM 서비스 → 사용자 → 보안자격증명 탭 → 액세스키 만들기 버튼 클릭 (아래 CMD 수행 위해 팝업창 유지)
$ echo "export AWS_ACCESS_KEY_ID=[키 ID 입력]" >> ~/.bash_profile
$ echo "export AWS_SECRET_ACCESS_KEY=[키 값 입력]" >> ~/.bash_profile
$ echo "export AWS_DEFAULT_REGION=[리전 ID 입력]" >> ~/.bash_profile
$ echo "export PATH=$PATH:~/environment" >> ~/.bash_profile
$ source ~/.bash_profile

- CodeCommit 자격증명 생성
IAM 서비스 → 사용자 → 보안자격증명 탭 → AWS CodeCommit에 대한 HTTPS Git 자격 증명 항목 → 자격증명 생성 버튼 클릭

- Terraform 소프트웨어 다운로드 및 압축 해제
브라우저에서 https://www.terraform.io/downloads.html 에 접속하여 Linux 64-bit 다운로드 링크 복사 
$ cd ~/environment
$ wget https://releases.hashicorp.com/terraform/0.13.3/terraform_0.13.3_linux_amd64.zip
$ unzip terraform_0.13.3_linux_amd64.zip

- 인스턴스 접속을 위한 키 페어 생성
$ cd ~/.ssh
$ ssh-keygen
엔터 3번하여 key 생성 완료


[Terraform 소스 적용]
※  테라폼 소스 적용 전 variable.tf  수정 및 확인 ※ 
$ cd ~/environment/final_pjt
$ terraform init
$ terraform plan
$ terraform apply --auto-approve


[어플리케이션 소스 적용]
WebAppRepo.zip 파일을 ~/environment로 이동 (실제 시험 때는 별도로 받아야 할듯)
$ mv ~/environment/final_pjt/WebAppRepo.zip ~/environment/
$ cd ~/environment
$ git clone https://git-codecommit.[리전 ID].amazonaws.com/v1/repos/WebAppRepo
(예 git clone https://git-codecommit.eu-west-1.amazonaws.com/v1/repos/WebAppRepo)
$ unzip WebAppRepo.zip
$ cd ~/environment/WebAppRepo
$ git add *
$ git config --global user.email "you@example.com"
$ git config --global user.name "Your Name"
$ git commit -m "Initial Commit"
$ git push -u origin master
CodePipeline 서비스 → 파이프라인 → 파이프라인 이름(userXX-CodePipeline) → 우측 상단쯤 재시작 버튼 클릭
Source - Build - Deploy 모두 성공(초록색) 확인 후 아래 테스트
EC2 서비스 → 로드밸런서 → 해당 ALB 선택 → DNS 이름 복사 → 인터넷 브라우저에 붙여넣기
"A Sample web application: Demo" 제목의 웹페이지가 보이면 성공


[테스트]
- Windows Powershell Script (로드밸런서 DNS 주소(http주소)를 복사하여 wget 이후부터 ;start-sleep 전까지의 http 주소를 치환)
for($i=0;$i -lt 3600;$i++){wget [여기에 로드밸런서 DNS 주소(http로 시작하는 주소) 붙여넣기];start-sleep -Seconds 1}
- 아래 사례 참고
for($i=0;$i -lt 3600;$i++){wget http://user111a-alb-8080-1993274192.us-east-2.elb.amazonaws.com:8080;start-sleep -Seconds 1}
for($i=0;$i -lt 3600;$i++){wget http://user11-alb1-1930552587.eu-west-1.elb.amazonaws.com/;start-sleep -Seconds 1}
- 아래 두 서비스 상태를 확인해서 인스턴스가 증가하는지 확인
CloudWatch 서비스 → 경보 → TargetTracking-(중략)-AlarmHigh-(후략) 클릭 → 그래프 확인
EC2 서비스 → Auto Scaling 그룹 → 해당 Auto Scaling 그룹에서 인스턴스 숫자 등 확인