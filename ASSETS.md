# 애셋 출처와 라이선스

| 파일 | 출처 | 라이선스 |
| --- | --- | --- |
| `fonts/NotoSansKR-Medium.ttf` | Google Fonts, Noto Sans KR (Medium 500) | SIL Open Font License 1.1 (상업 이용, 게임 동봉 가능) |
| `music/track1.ogg` | `tools/make_audio.py` 로 직접 합성한 임시 음악 | CC0 (직접 제작) |
| `sfx/*.wav` | `tools/make_audio.py` 로 직접 합성 | CC0 (직접 제작) |
| `icon.svg` | 직접 제작 | CC0 |
| 별, 탄, 기체, 배경 그래픽 | 모두 코드로 그림 (`scripts/game.gd`, `scripts/shapes.gd`) | 해당 없음 |

음악을 바꾸려면 `music/track1.ogg` 를 같은 이름으로 덮어쓰고, `scripts/track1.gd` 의 `LENGTH` 와 이벤트 시각을 곡에 맞추면 됩니다.
