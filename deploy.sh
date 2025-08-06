#!/bin/bash

# SNET 뉴스 앱 EKS 배포 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 설정값
AWS_REGION="ap-northeast-3"  # 오사카 리전
ECR_REPOSITORY="snet-news-app"
EKS_CLUSTER_NAME="your-eks-cluster-name"  # 실제 클러스터 이름으로 변경
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo -e "${BLUE}🚀 SNET 뉴스 앱 EKS 배포 시작${NC}"

# 1. ECR 레포지토리 생성 (존재하지 않는 경우)
echo -e "${YELLOW}📦 ECR 레포지토리 확인/생성...${NC}"
aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION || \
aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION

# 2. Docker 로그인
echo -e "${YELLOW}🔐 ECR에 Docker 로그인...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# 3. Docker 이미지 빌드
echo -e "${YELLOW}🔨 Docker 이미지 빌드...${NC}"
docker build -t $ECR_REPOSITORY:latest .

# 4. Docker 이미지 태그
echo -e "${YELLOW}🏷️ Docker 이미지 태그...${NC}"
docker tag $ECR_REPOSITORY:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
docker tag $ECR_REPOSITORY:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$(date +%Y%m%d-%H%M%S)

# 5. Docker 이미지 푸시
echo -e "${YELLOW}📤 Docker 이미지 ECR에 푸시...${NC}"
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$(date +%Y%m%d-%H%M%S)

# 6. EKS 클러스터 컨텍스트 업데이트
echo -e "${YELLOW}⚙️ EKS 클러스터 컨텍스트 업데이트...${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME

# 7. Kubernetes 매니페스트에서 이미지 URL 업데이트
echo -e "${YELLOW}📝 Kubernetes 매니페스트 업데이트...${NC}"
sed -i.bak "s|image: snet-news-app:latest|image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest|g" k8s/deployment.yaml

# 8. Kubernetes에 배포
echo -e "${YELLOW}🚢 Kubernetes에 배포...${NC}"
kubectl apply -f k8s/deployment.yaml

# 9. 배포 상태 확인
echo -e "${YELLOW}📊 배포 상태 확인...${NC}"
kubectl rollout status deployment/snet-news-app

# 10. 서비스 정보 출력
echo -e "${GREEN}✅ 배포 완료!${NC}"
echo -e "${BLUE}📋 서비스 정보:${NC}"
kubectl get pods -l app=snet-news-app
kubectl get svc snet-news-app-service
kubectl get ingress snet-news-app-ingress

# LoadBalancer URL 확인
echo -e "${BLUE}🌐 LoadBalancer URL:${NC}"
kubectl get ingress snet-news-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""

echo -e "${GREEN}🎉 SNET 뉴스 앱이 성공적으로 배포되었습니다!${NC}"