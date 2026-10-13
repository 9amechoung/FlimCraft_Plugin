# FlimCraft_Plugin

[![Verify patches](https://github.com/9amechoung/FlimCraft_Plugin/actions/workflows/verify.yml/badge.svg)](https://github.com/9amechoung/FlimCraft_Plugin/actions/workflows/verify.yml)

[FilmCraft](https://github.com/storytold/filmcraft)(오픈소스 Rust 영상 편집기)에 기능을 더하는 패치 모음입니다.
FilmCraft에는 플러그인 API가 없어서, 이 저장소의 패치를 FilmCraft 소스에 적용한 뒤 빌드하는 방식입니다.

| 패치 | 내용 |
|---|---|
| `0001-distance-and-space-audio-effect.patch` | 오디오 효과 **Distance & Space**(거리와 공간) |
| `0002-project-panel-image-sequence-import.patch` | Project 패널에서 바로 **이미지 시퀀스 불러오기**(우클릭·Alt+더블클릭·버튼·단축키) |
| `0003-image-sequence-frame-rate.patch` | 이미지 시퀀스를 불러올 때 **프레임레이트 고르기**(빨리감기처럼 보이는 문제 해결) |

기준 FilmCraft 버전: `FILMCRAFT_COMMIT` (0.7.2, `71438c6`)

## Distance & Space: 거리감·공간감 오디오 효과

앰비언트, 효과음, 대사에 "멀어진다 / 가까워진다 / 울린다"를 슬라이더 몇 개로 입힙니다.
위치: **Effects ▸ Audio Effects ▸ Reverb ▸ Distance & Space**

| 컨트롤 | 하는 일 |
|---|---|
| **Distance** (0.5–100 m) | 소리까지의 거리. 멀수록 작아지고(거리 2배마다 −6 dB), 고음이 깎이고(공기 흡수), 스테레오 폭이 좁아지며, 울림 비율이 커집니다. 1 m = 원음, 0.5 m = +6 dB |
| **Space** | 공간 프리셋: Open Air(야외) · Small Room(작은 방) · Living Room(거실, 기본) · Bathroom(욕실) · Concert Hall(콘서트홀) · Church(성당) · Cave(동굴) · Tunnel(터널) |
| **Reverb Amount** (0–200 %) | 울림의 양. 0 % = 울림 없음, 100 % = 프리셋 그대로, 200 % = 두 배 |
| **Position** (−100…+100) | 좌우 위치(직접음만, 울림은 넓게 유지) |
| **Air Absorption** (0–100 %) | 거리에 따른 고음 손실 정도 |
| **Doppler** | 켜면 거리가 변할 때 음높이가 변합니다(지나가는 차 소리). 거리/343 m/s 만큼 소리가 늦게 들립니다(10 m에서 29 ms) |
| **Output Gain** | 최종 볼륨 |

### 이렇게 쓰세요

- **멀어지는 소리**: Distance에 키프레임 두 개(시작 1 m → 끝 40 m)
- **다가오는 소리**: 반대로(40 m → 1 m). 차나 비행기라면 Doppler를 켜세요
- **울리는 공간**: Space를 Church나 Cave로 바꾸고, Reverb Amount로 양을 조절
- **멀리서 들리는 배경음(앰비언트)**: Distance 15–30 m, Space는 장면에 맞게
- **옆방 소리**: Distance 5 m, Space = Small Room, Air Absorption 100 %

Distance, Reverb Amount, Position, Air Absorption, Output Gain은 키프레임을 줄 수 있습니다.

## 이미지 시퀀스 빨리 불러오기

원래 FilmCraft에서는 **File ▸ Import Image Sequence…** 메뉴로만 불러올 수 있었고, 단축키도 없었습니다.
이 패치로 Project 패널에서 바로 부를 수 있습니다.

| 방법 | 동작 |
|---|---|
| 빈 곳 **우클릭** ▸ **Import Image Sequence…** | 파일 선택 창을 엽니다(List / Icon / Freeform 보기 모두) |
| 빈 곳 **Alt + 더블클릭** | 같은 창을 엽니다. 그냥 더블클릭은 기존처럼 일반 Import… 창을 엽니다 |
| 패널 아래 **그림 아이콘** 버튼 | 같은 창을 엽니다(새 빈(폴더) 버튼 옆) |
| **Ctrl+Alt+Shift+I** (macOS ⌘⌥⇧I) | 어디서든 같은 창을 엽니다. Keyboard Shortcuts에서 바꿀 수 있습니다 |

- 파일 창에서는 **첫 프레임 하나만** 고르거나 **Ctrl+A로 전부** 골라도 됩니다. 고른 것 중 번호가 가장 작은 프레임부터 시퀀스가 만들어집니다.
- 지금 패널에 열려 있는 빈(폴더)으로 들어갑니다.
- 파일을 고르면 **프레임레이트 창**이 뜹니다(0003). 아래 내용을 보세요.
- 그냥 더블클릭으로 연 일반 Import 창에서도 시퀀스로 받고 싶다면 **Settings ▸ Media ▸ Import numbered stills as image sequences**를 켜세요. 번호 붙은 이미지 하나를 고르면 시퀀스로 들어옵니다(원래 FilmCraft 기능).

### 프레임레이트 정하기(0003)

이미지 파일에는 프레임레이트 정보가 없습니다. 그래서 원래 FilmCraft는 시퀀스를 늘 **Settings ▸ Media ▸ Indeterminate Media Timebase** 값(기본 29.97 fps)으로 재생했습니다.
12 fps 애니메이션이나 24 fps 렌더 이미지를 불러오면, 원래보다 빨리 재생돼 **빨리감기처럼** 보였습니다.

이 패치를 쓰면 Import Image Sequence…에서 프레임을 고른 뒤 **Import Image Sequence** 창이 뜹니다.

| 항목 | 하는 일 |
|---|---|
| 파일 이름 · 프레임 수 | 들어올 시퀀스를 보여 줍니다 |
| **Frame Rate** 숫자 칸 | 1–240 fps 사이 아무 값이나 넣습니다(끌거나 더블클릭해서 입력) |
| 빠른 선택 버튼 | 8 · 10 · 12 · 12.5 · 15 · 23.976 · 24 · 25 · 29.97 · 30 · 48 · 50 · 59.94 · 60 |
| **Duration** | 고른 프레임레이트로 재생하면 몇 초인지 보여 줍니다 |
| **OK** / **Cancel** | OK를 누르면 그 프레임레이트로 불러오고, Cancel이나 Esc를 누르면 불러오지 않습니다 |

- 처음에는 Indeterminate Media Timebase 값으로 시작합니다. 그다음부터는 **마지막으로 고른 값**으로 시작합니다(앱을 다시 켜면 처음 값으로 돌아감).
- 고른 프레임레이트는 클립에 저장됩니다. 프로젝트를 저장했다가 다시 열어도 그대로 유지됩니다.
- 시퀀스를 30 fps로 편집하면서 12 fps 이미지를 쓰는 것처럼 타임라인과 프레임레이트가 달라도 됩니다. 길이(초)는 그대로 맞고, 각 그림이 여러 프레임 동안 보입니다.
- 이미 불러온 시퀀스의 속도는 바꿀 수 없습니다. 다시 불러오세요.
- Media Browser나 일반 Import 창의 자동 시퀀스 인식(위 설정)은 지금처럼 Indeterminate Media Timebase를 씁니다. 이 경로에 자주 쓰는 값이 있으면 그 설정을 바꿔 두세요.
- CinemaDNG처럼 파일 안에 프레임레이트가 적혀 있으면 그 값이 우선합니다.
- 자동화(engine 명령): `file.importImageSequence {"path": "...", "frameRate": 12}`. `file.import`에서도 `imageSequence: true`와 함께 `frameRate`를 쓸 수 있습니다.

## 설치(터미널 한 줄)

필요한 것: Git, [Rust](https://rustup.rs) 1.95 이상, Visual Studio C++ 빌드 도구(Windows).

FilmCraft 소스를 둘 폴더로 이동한 뒤(예: `cd C:\Dev`), PowerShell에 붙여 넣으세요.

> `C:\Program Files\FilmCraft`처럼 설치 프로그램으로 깐 FilmCraft에는 패치를 적용할 수 없습니다. 패치는 FilmCraft **소스 코드**에 적용해 새로 빌드하는 방식이라, 소스를 따로 내려받습니다. `Program Files`는 관리자 권한이 필요하니 소스 폴더로 쓰지 마세요. 기존에 설치한 FilmCraft는 그대로 두어도 됩니다.

```powershell
irm https://raw.githubusercontent.com/9amechoung/FlimCraft_Plugin/main/install.ps1 | iex
```

1. 이 저장소의 패치를 GitHub에서 내려받습니다.
2. FilmCraft를 현재 폴더의 `filmcraft`에 내려받습니다. 이미 있으면 그대로 씁니다.
3. 기준 커밋에서 `flimcraft-plugin` 브랜치를 만들고 패치를 적용합니다.
4. 빌드하고 실행합니다. 첫 빌드는 몇 분 걸립니다.

옵션을 쓰려면:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/9amechoung/FlimCraft_Plugin/main/install.ps1))) -Test
```

- `-Test`: 실행 전에 패치 관련 테스트를 돌립니다(`audio-dsp`, `project`, `render` 크레이트와 이미지 시퀀스 UI 테스트).
- `-NoRun`: 패치만 적용하고 빌드하지 않습니다.
- `-Target C:\경로\filmcraft`: 다른 FilmCraft 폴더를 씁니다. 커밋하지 않은 변경이 있으면 멈춥니다.

이 저장소를 클론했다면 `powershell -ExecutionPolicy Bypass -File .\install.ps1`로 로컬 패치를 씁니다.

## GitHub에서만 작업하기

로컬 클론 없이 GitHub만으로 관리할 수 있습니다.

- **자동 검증**: 푸시나 PR이 올라올 때마다 GitHub Actions(`.github/workflows/verify.yml`)가 Windows에서 다음을 실행합니다. 결과는 저장소의 **Actions** 탭에서 확인합니다.
  1. FilmCraft를 받아 패치를 적용합니다.
  2. 포맷과 clippy 검사를 합니다.
  3. 테스트와 UI 번역 검사를 돌립니다.
- **수동 실행**: Actions ▸ Verify patches ▸ **Run workflow**
- **문서나 설정 수정**: github.com에서 파일을 열고 연필 아이콘으로 편집해 커밋하면, 검증이 자동으로 돕니다.
- **패치 내용 수정**: 패치 파일은 FilmCraft 소스와의 차이(diff)라서 웹에서 직접 고치기 어렵습니다. 저장소 페이지의 **Code ▸ Codespaces**로 브라우저 안 개발 환경을 열면, 로컬 설치 없이 `install.ps1 -NoRun`으로 패치를 적용해 수정하고 다시 패치로 저장할 수 있습니다.
- **설치**: 위의 한 줄 명령은 항상 GitHub의 `main` 브랜치에서 받아오므로, 로컬 폴더가 없어도 됩니다.

## 동작 원리(개발자용)

- DSP: `crates/audio-dsp/src/effects/spatial.rs`의 `Space` 효과입니다. 기존 8×8 FDN `Reverb`를 그대로 씁니다. 직접음은 거리 역제곱 감쇠, 2단 one-pole 저역통과(공기 흡수), 거리에 따른 M/S 폭 축소를 거칩니다. 도플러는 분수 지연선입니다. 울림은 거리에 따라 직접음보다 훨씬 천천히 줄어서(100 m에서 −8 dB), 먼 소리일수록 울림 비중이 커집니다.
- 등록 위치: DSP 레지스트리(`effects/mod.rs`), 프로젝트 효과 정의(`project/src/effect/audio.rs`, id `space`), 렌더 매핑(`render/src/audio_fx.rs`의 `DIRECT`, 프리롤 3초), 스페인어·일본어 UI 번역(`ui-egui/src/i18n/*.tsv`).
- 이미지 시퀀스(0002): 명령 `file.importImageSequence`에 기본 단축키(`engine/src/project_tools.rs`)를 주고, Project 패널의 빈 곳 메뉴·더블클릭(`ui-egui/src/panels/project_views.rs`)과 하단 버튼(`panels/project.rs`)에서 부릅니다. 파일 창 처리(`ui-egui/src/lib.rs`의 `file_dialog`)는 보이는 빈을 기본값으로 쓰고, 여러 프레임을 고르면 번호가 가장 작은 것부터 시작합니다(`first_numbered_frame`).
- 프레임레이트(0003): 엔진 `file.import`·`file.importImageSequence`가 `frameRate`(숫자 또는 `"23.976"` 같은 문자열, 1–240)를 받아 `import_image_sequence`(`engine/src/commands.rs`)에 넘깁니다. 미디어 항목의 프레임레이트로 저장되므로 프로젝트를 다시 열어도 유지됩니다(`media_pool.rs`가 `m.info.frame_rate()`로 다시 엽니다). UI는 파일 창 다음에 `ui-egui/src/panels/image_sequence_dialog.rs` 창을 띄웁니다. `frameRate`를 함께 주면 창 없이 바로 불러옵니다.
- 패치를 새로 만들려면: `install.ps1 -NoRun`으로 기존 패치가 적용된 `flimcraft-plugin` 브랜치에서 수정한 뒤 `git diff HEAD > patches/000N-이름.patch`(기존 패치 위의 차이만), 그리고 `patches/series`에 파일 이름을 한 줄 추가합니다.
