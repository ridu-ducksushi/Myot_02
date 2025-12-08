# PetCare Flutter 앱 개발 룰

## 코딩 룰 (우선순위 순)

### 1. KISS & DRY 원칙 (최우선)
- Keep It Simple, Stupid - 단순하게, 과도한 엔지니어링 금지
- Don't Repeat Yourself - 반복되는 로직은 메서드로 추출
- 변수와 메서드명은 의도를 명확히 드러내는 이름 사용

### 1-1. 단일 진실의 원천 (Single Source of Truth)
- 데이터나 상태는 하나의 소스에서만 관리
- 동일한 데이터를 여러 곳에서 중복 저장하지 않음
- 상태 동기화 문제 방지를 위해 중앙화된 상태 관리 사용
- 예: Riverpod Provider를 통한 상태 관리, Supabase를 단일 데이터 소스로 사용

### 2. Unity Lifecycle Safety
- 생명주기 메서드 중복 금지 (Update, Start, Awake 등)
- OnDestroy에서 새로운 GameObject 생성 금지
- [SerializeField] private 필드와 프로퍼티 접근 사용

### 3. Null Safety & Error Logging
- 객체/컴포넌트 접근 전 항상 null 체크
- 예상치 못한 상황은 Debug.LogError/LogWarning으로 로깅
- 프로덕션 코드에서 NullReferenceException 방지

### 4. Short Methods & Single Responsibility
- 메서드는 30줄 이하로 유지
- 하나의 메서드는 하나의 명확한 책임만
- 복잡한 로직은 작은 헬퍼 메서드로 분리

### 5. Component Caching
- Update나 FixedUpdate에서 GetComponent/Find 사용 금지
- Start/Awake에서 컴포넌트 참조 캐싱
- 가능하면 TryGetComponent 사용

### 6. Basic Error Prevention
- 누락된 using 문 체크
- 메서드 호출 전 메서드명 존재 여부 검증
- 린터 에러 없음을 항상 확인

### 7. Side Effect Awareness
- 변경 시 기존 코드에 미치는 영향 고려
- 다른 스크립트와의 상호작용 검토
- 제안 시 잠재적 위험 언급

## 데이터베이스 매핑 룰

### 8. Supabase 컬럼명 자동 변환 규칙
- **Flutter (camelCase) → Supabase (snake_case)** 자동 변환 필수
- 모든 Repository 클래스에서 데이터 저장/조회 시 변환 적용
- 변환 예시:
  - `ownerId` → `owner_id`
  - `birthDate` → `birth_date`
  - `weightKg` → `weight_kg`
  - `avatarUrl` → `avatar_url`
  - `bloodType` → `blood_type`
  - `createdAt` → `created_at`
  - `updatedAt` → `updated_at`
  - `petId` → `pet_id`

### 9. Repository 패턴 준수
- Supabase 저장 시 `_toSupabaseRow()` 메서드로 변환
- Supabase 조회 시 `_fromSupabaseRow()` 메서드로 역변환
- camelCase 모델을 직접 Supabase에 저장하지 않기

## 프로젝트 특화 룰

### 10. MCP 활용
- 필요한 MCP를 직접 활용 (웹 개발: Playwright, 태스크 관리: Task Manager 등)
- 프로젝트 룰 파일을 생성하여 대화 내용 중 기억해야 할 내용 저장

### 11. 사용자 데이터 격리
- SharedPreferences 키에 사용자 ID 스코프 적용
- 로그인/로그아웃 시 다른 사용자 데이터 노출 방지
- UUID 검증을 통한 Supabase 호환성 보장

### 12. 에러 처리 및 폴백
- Supabase 저장 실패 시 로컬 저장으로 폴백
- 네트워크 오류 시 사용자에게 적절한 피드백 제공
- 모든 외부 API 호출에 try-catch 적용
