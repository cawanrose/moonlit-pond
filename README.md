# 폴짝, 달빛 연못 (Moonlit Pond)

Godot 4.7.2 · Android · 제작 moonshot2026

## 이 저장소에 있는 것
- `game/` — 게임 코드와 씬, 프로젝트 설정 (v1.13, build 113)
  - 직접 수정해 온 스크립트: `scripts/main.gd`, `intro.gd`, `giant_koi.gd`, `turtle.gd`, `lily_pad.gd`, `frog.gd`, `ripple.gd`, `giant_fish.gd`, `*.gdshader`
  - 나머지 `*.gdc` 는 원본 빌드(v0.71)에서 넘어온 컴파일된 스크립트
- `tools/pack.py` — APK 다시 묶는 스크립트 (서명은 별도)
- `tools/*.gd`, `tools/web_shell.html` — 웹 버전 빌드용

## 여기에 없는 것
- 아트 리소스(이미지, 사운드, 폰트, 아이콘): `D:\Godot_Artdata\Moonlit Pond\backup\` 에 버전별 zip 으로 보관
- 서명 키(keystore)와 비밀번호: 저장소에 절대 올리지 않음

## 최근 변경
- v1.13 — 점프/착지 "뿅" 소리 절반(-6dB)
- v1.12 — 반투명 거북이 관절 겹침 해결(CanvasGroup), 제작 표기 10% 키움
- v1.11 — 재시작하면 인트로부터 다시 시작
- v1.10 — 물길·연잎 충돌·연잎 사라짐 때 번쩍임 제거
- v1.09 — 효과음 버스(저역 통과+잔향), BGM +4dB, 효과음 약 10dB 아래로
- v1.08 — 효과음 버스 도입, 두 번째 튕김 소리 제거
- v1.07 — 연못 물소리·리듬 차임 감소
- v1.06 — 인트로 전환 때 레이어 가장자리 잘림 수정
- v1.04~1.05 — 새 인트로(GPT 레이어), 새 아이콘
