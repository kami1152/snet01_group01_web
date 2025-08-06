# Flutter 웹 앱을 위한 가벼운 Docker 빌드

# 1단계: 가벼운 베이스 이미지에서 Flutter 설치
FROM ubuntu:22.04 AS builder

# 환경 변수 설정
ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME="/opt/flutter"
ENV PATH="$FLUTTER_HOME/bin:$PATH"

# 필수 패키지 설치
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Flutter SDK 다운로드 (최신 stable 버전)
RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_HOME

# Flutter 웹 활성화
RUN flutter config --enable-web
RUN flutter doctor

# 작업 디렉토리 설정
WORKDIR /app

# pubspec 파일들 복사 및 의존성 설치
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 소스 코드 복사
COPY . .

# 웹 빌드 실행
RUN flutter build web --release --web-renderer html

# 2단계: Nginx로 정적 파일 서빙
FROM nginx:alpine

# Nginx 설정 복사
COPY nginx.conf /etc/nginx/nginx.conf

# Flutter 빌드 결과물 복사
COPY --from=builder /app/build/web /usr/share/nginx/html

# 포트 노출
EXPOSE 80

# Nginx 실행
CMD ["nginx", "-g", "daemon off;"]