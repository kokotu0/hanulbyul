# 애셋 출처와 라이선스

## 그래픽

| 파일 | 원본 | 만든 이 | 라이선스 |
| --- | --- | --- | --- |
| `assets/ships/player.png` | Space Shooter Redux 의 `PNG/playerShip3_blue.png` (원본 그대로) | Kenney (kenney.nl) | CC0 1.0 |
| `assets/fx/flare.png` | Particle Pack 의 `flare_01.png` | Kenney | CC0 1.0 |
| `assets/fx/sparkle.png` | Particle Pack 의 `star_06.png` | Kenney | CC0 1.0 |
| `assets/fx/star_burst.png` | Particle Pack 의 `star_08.png` | Kenney | CC0 1.0 |
| `assets/fx/ring.png` | Particle Pack 의 `circle_02.png` | Kenney | CC0 1.0 |
| `assets/fx/streak.png` | Particle Pack 의 `trace_07.png` (잘라냄) | Kenney | CC0 1.0 |
| `assets/fx/flame.png` | Particle Pack 의 `flame_05.png` (잘라냄) | Kenney | CC0 1.0 |
| `assets/fx/smoke_a.png` | Particle Pack 의 `smoke_07.png` | Kenney | CC0 1.0 |
| `assets/fx/smoke_b.png` | Particle Pack 의 `smoke_04.png` | Kenney | CC0 1.0 |
| `assets/fx/reticle.png` | Particle Pack 의 `magic_03.png` | Kenney | CC0 1.0 |
| `assets/fx/glow.png` | 직접 생성한 가우시안 빛 번짐 | 직접 제작 | CC0 |

- 원본 페이지: Space Shooter Redux <https://kenney.nl/assets/space-shooter-redux>, Particle Pack <https://kenney.nl/assets/particle-pack>
- kenney.nl 직접 접속이 막혀 있어 같은 파일을 담은 GitHub 공개 사본에서 받았다:
  - `https://raw.githubusercontent.com/mlm-games/asteroids-revenge/main/art-and-sound/kenney_space-shooter-redux/PNG/playerShip3_blue.png`
  - `https://raw.githubusercontent.com/devloglogan/MultiplayerFPSTutorial/main/addons/kenney_particle_pack/<이름>.png`
- 파티클 텍스처는 흰색 + 알파로 바꾸고(밝기를 알파에 곱함) 128~256px 로 줄였다. 게임에서 modulate 로 색을 입힌다.
- Kenney 애셋은 CC0 (퍼블릭 도메인) 이라 표기 의무는 없지만 감사의 뜻으로 적어 둔다.

## 글꼴

| 파일 | 원본 | 라이선스 |
| --- | --- | --- |
| `fonts/Pretendard-SemiBold.otf` (기본 UI 글꼴) | Pretendard (main 브랜치), 길형진 (orioncactus) <https://github.com/orioncactus/pretendard> — `packages/pretendard/dist/public/static/Pretendard-SemiBold.otf` | SIL Open Font License 1.1 |
| `fonts/Pretendard-Black.otf` (제목) | 같은 곳, `Pretendard-Black.otf` | SIL Open Font License 1.1 |

라이선스 전문: `fonts/Pretendard-OFL.txt`. 게임에 동봉·상업 이용 가능, 글꼴 파일만 따로 파는 것은 안 됨.

## 소리

| 파일 | 출처 | 라이선스 |
| --- | --- | --- |
| `music/track1.ogg` | `tools/make_audio.py` 로 직접 합성한 임시 음악 | CC0 (직접 제작) |
| `sfx/*.wav` | `tools/make_audio.py` 로 직접 합성 | CC0 (직접 제작) |
| `icon.svg` | 직접 제작 | CC0 |

탄 모양(쌀알·화살촉·구슬·8각 별)과 그림 별 반짝이는 판정 크기를 정확히 맞추려고 코드로 그린다 (`scripts/game.gd` 의 `_draw_bullets`). 위의 빛 텍스처는 그 아래 더하기 층에서 번짐·꼬리·섬광으로만 쓴다.

음악을 바꾸려면 `music/track1.ogg` 를 같은 이름으로 덮어쓰고, `scripts/track1.gd` 의 `LENGTH` 와 이벤트 시각을 곡에 맞추면 됩니다.
