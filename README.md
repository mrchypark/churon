# churon: ONNX Runtime Integration for R

[![R-CMD-check](https://github.com/churon-project/churon/workflows/R-CMD-check/badge.svg)](https://github.com/churon-project/churon/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

churon은 R에서 ONNX Runtime을 사용하여 머신러닝 추론을 수행할 수 있게 해주는 패키지입니다. 특히 한국어 텍스트 처리 모델, 특히 한국어 띄어쓰기(kospacing) 모델에 특화된 지원을 제공합니다.

## 주요 특징

- 🚀 **고성능**: Rust로 구현된 핵심 로직으로 빠른 성능
- 🛡️ **메모리 안전성**: Rust의 메모리 안전성 보장
- 🔧 **포괄적인 에러 처리**: 상세한 에러 메시지와 검증
- 🌐 **다중 실행 제공자**: CUDA, TensorRT, DirectML, OneDNN, CoreML, CPU 지원
- 🇰🇷 **한국어 특화**: 한국어 텍스트 처리 모델 내장

## 설치

### 시스템 요구사항

- R (>= 4.0.0)
- Rust (>= 1.70.0)
- ONNX Runtime (>= 1.13.0) - 자동으로 다운로드됩니다

### 설치 방법

```r
# GitHub에서 설치
# devtools::install_github("churon-project/churon")

# 또는 로컬에서 빌드
R CMD build .
R CMD INSTALL churon_0.0.0.9000.tar.gz
```

## 빠른 시작

### 기본 사용법

```r
library(churon)

# 사용 가능한 예시 모델 확인
models <- onnx_example_models()
print(models)

# 모델 로딩
session <- onnx_session(models["kospacing"])

# 모델 정보 확인
print(session)

# 입력/출력 정보 조회
input_info <- onnx_input_info(session)
output_info <- onnx_output_info(session)

print(input_info[[1]]$name)    # 입력 텐서 이름
print(input_info[[1]]$shape)   # 입력 텐서 형태
print(input_info[[1]]$data_type) # 입력 텐서 데이터 타입
```

### 안전한 세션 생성

```r
# 에러 처리가 포함된 안전한 세션 생성
session <- safe_onnx_session("path/to/model.onnx", optimize = TRUE)

if (!is.null(session)) {
  # 세션 사용
  providers <- onnx_providers(session)
  cat("사용 가능한 실행 제공자:", paste(providers, collapse = ", "), "\n")
}
```

### 유틸리티 함수

```r
# 모델 경로 찾기
model_path <- find_model_path("kospacing")

# ONNX Runtime 정보 확인
runtime_info <- get_onnx_runtime_info()
print(runtime_info)

# ONNX Runtime 사용 가능 여부 확인
if (check_onnx_runtime_available()) {
  cat("ONNX Runtime이 사용 가능합니다!\n")
}
```

## API 참조

### 핵심 함수

- `onnx_session(model_path, providers = NULL)`: ONNX 세션 생성
- `onnx_run(session, inputs)`: 추론 실행 (현재 제한적)
- `onnx_input_info(session)`: 입력 텐서 정보 조회
- `onnx_output_info(session)`: 출력 텐서 정보 조회
- `onnx_providers(session)`: 실행 제공자 조회

### 유틸리티 함수

- `onnx_example_models()`: 예시 모델 목록
- `find_model_path(model_name)`: 모델 경로 찾기
- `safe_onnx_session(...)`: 안전한 세션 생성
- `check_onnx_runtime_available()`: 런타임 사용 가능 여부 확인

## 현재 상태 및 제한사항

### ✅ 완전히 작동하는 기능

- ONNX 모델 로딩 및 세션 관리
- 모델 메타데이터 추출 및 조회
- 다양한 실행 제공자 지원
- 포괄적인 에러 처리
- 유틸리티 함수들

### ⚠️ 제한사항

- **추론 실행**: 현재 텐서 변환이 완전히 구현되지 않아 실제 추론 실행(`onnx_run`)은 제한적입니다
- **성능 최적화**: 일부 고급 성능 최적화 기능이 미완성입니다
- **문서화**: 일부 함수의 문서화가 누락되어 있습니다

## 개발 로드맵

- [ ] ONNX 텐서 변환 로직 완성
- [ ] 실제 추론 실행 기능 완성
- [ ] 성능 최적화 기능 구현
- [ ] 포괄적인 문서화
- [ ] 추가 플랫폼 지원 (Windows, Linux)
- [ ] 더 많은 예시 모델 추가

## 기여하기

1. 이 저장소를 포크합니다
2. 기능 브랜치를 생성합니다 (`git checkout -b feature/amazing-feature`)
3. 변경사항을 커밋합니다 (`git commit -m 'Add amazing feature'`)
4. 브랜치에 푸시합니다 (`git push origin feature/amazing-feature`)
5. Pull Request를 생성합니다

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 지원

- 이슈: [GitHub Issues](https://github.com/churon-project/churon/issues)
- 문서: [패키지 문서](https://churon-project.github.io/churon/)

## 감사의 말

- [ONNX Runtime](https://onnxruntime.ai/) 팀
- [extendr](https://github.com/extendr/extendr) 프로젝트
- R 커뮤니티

---

**참고**: 이 패키지는 현재 개발 중이며, 일부 기능이 제한적일 수 있습니다. 프로덕션 환경에서 사용하기 전에 충분한 테스트를 권장합니다.