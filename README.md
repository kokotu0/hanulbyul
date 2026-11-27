# 하떨별 (MVP)

노래 한 곡 동안 별 노드가 그림을 만들며 쏟아지는 탄을 피하는 탄막 게임. Godot 4.3 이상.

## 실행

1. Godot 4.3+ 에서 `project.godot` 열기 → F5
2. 메뉴에서 **게임 시작** 또는 **수치 테스트 화면**

## 조작

| 입력 | 동작 |
| --- | --- |
| WASD / 방향키 | 이동 |
| 큰 별 클릭 (왼쪽·오른쪽) | 조준 후 사거리 안이면 자동 사격. 키를 놓고 있으면 사거리까지 따라감. 부수면 주변 노드가 무너지고 다음 큰 별을 자동으로 노림. 빈 곳 클릭은 조준 해제 |
| Space | 대시 (마우스 쪽, 돌진 중 무적, 3.5초) |
| Q | 섬광 (주변 작은 탄 지우기, 14초) |
| Tab (누르고 있기) | 전체 맵 보기 |
| Esc | 일시정지 |

## 게임 규칙

- HP 5칸. 맞으면 1칸 줄고 1.6초 무적. 다 닳으면 추락, 곡 끝까지 버티면 클리어 (맞은 횟수로 등급).
- 초록 테두리 안(활동 구역)에서만 움직임. 바깥 여유 구역에서 들어오는 탄 벽은 1.2초 전에 노란 경고선과 초록 틈으로 미리 보임.
- 어떤 별·탄도 기체 속도의 90%보다 빠르지 않음.
- 큰 별은 결전 이후 기체를 노려 3갈래 탄을 쏨.
- 별(드론)은 무리 이벤트마다 새로 태어남. 태어나는 자리에 빛 고리가 퍼지고, 그 중심에서 별들이 쏟아져 나와 각자 자리로 날아감. 무리가 끝나면 맵 끝으로 흩어지거나 중심으로 모여 사라짐.

## 트랙 1 "별이 내리는 밤" (96초, 120 BPM)

도입 → 집결 → 숨 고르기 → 결전 → 다리 → 피날레 → 끝맺음.
장면 전환(그림이 바뀌는 순간)은 다섯 번이고, 전환과 하이라이트 때 화면이 번쩍이며 별이 확 흩어졌다 몰려감.
하이라이트 직전과 숨 고르기 구간은 탄을 비워 쉬는 시간을 둠. 레벨 데이터는 `scripts/track1.gd`.

## 수치 테스트 화면

핵심 수치 다섯 묶음을 슬라이더로 바로 바꿔 볼 수 있음. 값은 `user://tune.cfg` 에 저장되어 본 게임에도 그대로 쓰임.
**값 복사** 버튼으로 현재 값을 클립보드에 복사해 공유.

1. 화면 범위 대 맵 크기: 맵 크기(기본 화면의 몇 배), 화면 확대
2. 기체와 판정 크기
3. 노드 간격
4. 기체 대 노드 속도
5. 사거리와 공격 주기

그 밖에 HP, 바깥 여유 구역 폭, 장면별 배경색 세기, 무적, 구간 바로가기.

## 파일 구조

| 파일 | 내용 |
| --- | --- |
| `scripts/game.gd` | 게임 진행, 드론 움직임, 충돌, 그리기, HUD |
| `scripts/track1.gd` | 트랙 1 레벨 데이터 (이벤트 타임라인) |
| `scripts/shapes.gd` | 그림 정의, 노드 좌표 샘플링, 색 팔레트, 이미지 → 그림 |
| `scripts/player_state.gd` | 기체 한 대의 상태 (협동 멀티 대비) |
| `scripts/skills.gd` | 스킬 정의 |
| `scripts/tune.gd` | 핵심 수치 (autoload) |
| `scripts/tune_panel.gd` | 테스트 화면 슬라이더 패널 |
| `scripts/minimap.gd` | 격자 미니맵 |
| `tools/make_audio.py` | 임시 음악과 효과음 합성 |
| `tools/video_to_level.py` | 뮤직비디오 → 레벨 JSON 변환기 |
| `scripts/video_level.gd` | 변환된 레벨 JSON 읽기 (Track1 과 같은 형식으로 돌려줌) |
| `tests/autoplay.gd` | 자동 플레이 테스트 |

## 다음 단계에 붙일 것 (구조는 준비됨)

- **협동 멀티**: 기체 상태가 `PlayerState` 로 분리되어 있고 `players` 배열을 돌며 이동·피격·부활을 처리함. 쓰러진 동료 위에 2.5초 머물면 부활하는 로직(`_update_revive`)이 이미 들어 있음. 네트워크 동기화만 붙이면 됨.
- **스킬 추가**: `scripts/skills.gd` 에 항목 하나, `game.gd` 의 `use_skill()` 에 분기 하나.
- **뮤직비디오 → 레벨 자동 생성**: 변환기는 아래 "뮤직비디오로 레벨 만들기" 참고. 게임이 `Track1.*` 대신 `VideoLevel.load_level()` 결과를 읽게 하는 연결만 남음.

## 뮤직비디오로 레벨 만들기

```
python3 tools/video_to_level.py 뮤비.mp4 --name mv1 --bpm 128 --audio --preview-dir 미리보기폴더/
```

- 장면 전환(컷)을 찾아 가장 뚜렷한 것만 **최대 5개**(서로 8초 이상 간격) 남기고, 마디 경계에 맞춘다.
- 한 마디(`--hold-beats 4`, 120 BPM 이면 2초)마다 프레임 하나를 골라 윤곽·밝기가 강한 칸을 엇갈린 격자에서 뽑아 별 좌표로 만든다. 별 수는 `--stars`(기본 240), 별 사이 최소 간격은 화면 너비 / `--cols`(기본 36).
- 앞뒤 키프레임의 별을 최소 이동으로 짝지어(헝가리안) 같은 별이 조금씩 움직이며 그림을 따라가고, 컷에서는 snap 과 함께 새 그림으로 확 몰려간다. 색은 프레임에서 뽑아 `Shapes.PALETTE` 색으로 맞춘다.
- 결과: `levels/<이름>.json` (키프레임 좌표·색, 컷, 장면 세기, Track1 형식의 SECTIONS / EVENTS). `--audio` 면 `music/<이름>.ogg` 도 뽑는다. `--preview-dir` 를 주면 장면마다 원본 | 별 미리보기 PNG.
- `--mode scene` 이면 장면마다 새 무리(컷에서 이전 무리는 모여 사라지고 새 무리가 터져 나옴), 기본 `song` 은 곡 전체를 한 무리가 맡는다.
- 게임에서: `var lv := VideoLevel.load_level("res://levels/mv1.json")` → 그림이 `Shapes.register_points` 로 등록되고 `lv.EVENTS`, `lv.SECTIONS`, `lv.LENGTH` 등이 Track1 상수와 같은 모양으로 들어 있다.
- 검사: `VIDEO_LEVEL=res://levels/mv1.json godot --headless --path . res://tests/video_level_check.tscn`
- 필요: ffmpeg, python3 + numpy + Pillow (scipy 는 있으면 사용). 내보내기(export) 때는 `levels/*.json` 을 export 필터의 비리소스 파일에 넣어야 한다.

## 테스트

```
godot --headless --path . --fixed-fps 60 res://tests/autoplay.tscn
```

곡 끝까지 자동 플레이(회피 + 큰 별 공격)하고 결과를 출력. `AUTOPLAY_SHOTS=폴더` 를 주면 화면 캡처(렌더링 가능한 환경 필요), `AUTOPLAY_INVINCIBLE=0` 이면 무적 끔, `AUTOPLAY_TEST=1` 이면 테스트 화면으로 실행.

애셋 출처는 [ASSETS.md](ASSETS.md).
