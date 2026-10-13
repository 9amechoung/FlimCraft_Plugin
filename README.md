# FlimCraft_Plugin

[FilmCraft](https://github.com/storytold/filmcraft)(오픈소스 Rust 영상 편집기)에 기능을 더하는 패치 모음입니다.
FilmCraft에는 플러그인 API가 없어서, 이 저장소의 패치를 FilmCraft 소스에 적용한 뒤 빌드하는 방식입니다.

| 패치 | 내용 |
|---|---|
| `0001-distance-and-space-audio-effect.patch` | 오디오 효과 **Distance & Space**(거리와 공간) |

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

- `-Test`: 실행 전에 패치 관련 테스트를 돌립니다(`audio-dsp`, `project`, `render` 크레이트).
- `-NoRun`: 패치만 적용하고 빌드하지 않습니다.
- `-Target C:\경로\filmcraft`: 다른 FilmCraft 폴더를 씁니다. 커밋하지 않은 변경이 있으면 멈춥니다.

이 저장소를 클론했다면 `powershell -ExecutionPolicy Bypass -File .\install.ps1`로 로컬 패치를 씁니다.

> 상태: 패치는 FilmCraft 0.7.2에 적용되는 것까지 확인했고, 빌드·테스트 검증은 진행 중입니다.

## 동작 원리(개발자용)

- DSP: `crates/audio-dsp/src/effects/spatial.rs`의 `Space` 효과입니다. 기존 8×8 FDN `Reverb`를 그대로 씁니다. 직접음은 거리 역제곱 감쇠, 2단 one-pole 저역통과(공기 흡수), 거리에 따른 M/S 폭 축소를 거칩니다. 도플러는 분수 지연선입니다. 울림은 거리에 따라 직접음보다 훨씬 천천히 줄어서(100 m에서 −8 dB), 먼 소리일수록 울림 비중이 커집니다.
- 등록 위치: DSP 레지스트리(`effects/mod.rs`), 프로젝트 효과 정의(`project/src/effect/audio.rs`, id `space`), 렌더 매핑(`render/src/audio_fx.rs`의 `DIRECT`, 프리롤 3초), 스페인어·일본어 UI 번역(`ui-egui/src/i18n/*.tsv`).
- 패치를 새로 만들려면: FilmCraft 쪽에서 수정한 뒤 `git diff 71438c6 > patches/000N-이름.patch`, 그리고 `patches/series`에 파일 이름을 한 줄 추가합니다.
