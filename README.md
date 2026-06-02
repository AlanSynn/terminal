# workstation-bootstrap

Alan의 macOS + Ubuntu 개발 환경을 새 컴퓨터에 재현하기 위한 **Init v2 / workstation bootstrap repo**입니다. 첫 경험은 `oh-my-zsh`처럼 단순해야 하므로, 사용자는 `./install.sh`만 실행하고 profile/tier/audit/apply 여부는 터미널 인터페이스에서 고릅니다.

> 현재 Linux 범위는 **Ubuntu 24.04 LTS 계열**입니다. Fedora/Arch/Nix는 의도적으로 보류합니다.

## 가장 빠른 시작

```bash
git clone <repo-url> ~/Workspace/src/Management/terminal
cd ~/Workspace/src/Management/terminal
./install.sh
```

`install.sh`의 원칙:

- 설치 선택지는 커맨드라인 파라미터가 아니라 **번호 선택 메뉴(드롭다운 같은 TTY 인터페이스)**로 고릅니다.
- Enter를 누르면 안전한 기본값으로 진행합니다.
- 기본 action은 **preview/dry-run**입니다.
- 실행마다 `run id`, `Planned flow`, `[FLOW 1/3]` 같은 단계 표시가 나와서 어디까지 왔는지 추적할 수 있습니다.
- 실제 적용은 메뉴에서 `apply`를 고른 뒤 `APPLY`를 직접 입력해야 합니다.
- 자동화/CI/디버깅이 필요할 때만 하위 엔진인 `bootstrap.sh`를 직접 호출합니다.

메뉴 흐름:

1. **Profile** — `personal`, `work`, `minimal`, `ci`
2. **Install tier** — `minimal`, `cli`, `full`, `ci`
3. **Preflight audit** — `standard`, `full`, `none`
4. **Action** — `preview`, `apply`, `plan only`, `quit`

일반적인 선택:

| 원하는 결과 | 메뉴에서 고를 값 |
| --- | --- |
| 무엇이 실행될지만 확인 | `personal` → `cli` → `standard` → `plan only` |
| 터미널/CLI 환경 안전 preview | `personal` → `cli` → `standard` → `preview` |
| 최소 dotfile/base tool 적용 | `minimal` → `minimal` → `standard` → `apply` |
| Mac 전체 GUI/MAS/VS Code까지 preview | `personal` → `full` → `full` → `preview` |
| CI/container 검증 | `ci` → `ci` → `none` 또는 `standard` → `preview` |

## 실행 흐름 추적

메뉴 선택이 끝나면 installer가 먼저 선택 요약과 planned flow를 출력합니다.

```text
Selected plan
-------------
profile:  personal
tier:     cli
audit:    standard
action:   dry-run

Planned flow
------------
run id:   20260602T201511Z-12345
1. selection       complete; profile=personal tier=cli audit=standard action=dry-run
2. preflight       secret scan + private risk audit
3. bootstrap       preview bootstrap for personal/cli
4. finish          final status and next-step signal
```

실제로 실행되는 동안에는 wrapper 단계가 이렇게 표시됩니다.

```text
[FLOW 1/3] preflight audits: standard
[FLOW 2/3] bootstrap engine: profile=personal tier=cli action=dry-run
[FLOW 3/3] installer complete: run id 20260602T201511Z-12345
```

이 흐름은 영구 로그 파일을 기본 생성하지 않고 화면에만 보여줍니다. 자세한 dry-run 출력은 그대로 `bootstrap.sh` 단계 로그에서 확인합니다.

## 설치 선택지

### Profile

| Profile | 의미 |
| --- | --- |
| `personal` | 기본 개인 환경. 기본값. |
| `work` | work profile용 hook/data 자리. 현재는 보수적으로 유지. |
| `minimal` | 최소 dotfile/profile 렌더용. |
| `ci` | 검증/컨테이너 친화 경로. |

### Tier

| Tier | 포함 범위 |
| --- | --- |
| `minimal` | native prerequisites, Homebrew/Linuxbrew, common packages, chezmoi dotfiles, verify |
| `cli` | `minimal` + npm/bun/uv/cargo language tools. **추천 기본값** |
| `full` | `cli` + macOS GUI casks, MAS apps, VS Code extensions, OS defaults |
| `ci` | dry-run/container 검증 친화 경로 |

### Audit level

| Audit | 실행 내용 |
| --- | --- |
| `none` | installer preflight audit 생략 |
| `standard` | `scripts/verify-no-secrets.sh` + `just private-risk-audit`. 기본값 |
| `full` | standard + `just public-audit` |

## 설치가 실제로 하는 일

`install.sh`는 첫 실행 UX wrapper입니다. 실제 작업은 계속 `bootstrap.sh`가 수행합니다.

1. 선택한 preflight audit 실행
2. `scripts/doctor.sh`
3. macOS CLT 또는 Ubuntu apt prerequisites
4. Homebrew/Linuxbrew 확인 또는 설치
5. tier별 package manifest 처리
6. `cli/full/ci`에서 language tools 처리
7. `full`에서 VS Code extensions 및 macOS GUI/MAS apps 처리
8. chezmoi diff/apply
9. macOS/Linux defaults
10. `scripts/verify-new-machine.sh`

고급 자동화나 테스트에서는 엔진을 직접 호출할 수 있습니다. 단, 새 컴퓨터에서 사람이 쓰는 기본 경로는 항상 `./install.sh`입니다.

```bash
./bootstrap.sh --dry-run --profile personal --tier cli
./bootstrap.sh --profile personal --tier cli
```

## Terminal parity

현재 Mac terminal 환경과 같아야 하는 파일은 repo에서 관리합니다.

- zsh: `dot_zshrc.tmpl`, `dot_zshrc.alan.tmpl`, `dot_zshenv.tmpl`, `dot_shell.alan`
- tmux: `dot_tmux.conf`, `dot_tmux.conf.local`
- git/vim/fzf: `dot_gitconfig`, `dot_gitignore`, `dot_vimrc`, `dot_fzf.zsh`
- SSH/GPG agent config: `private_dot_ssh/...`, `private_dot_gnupg/gpg-agent.conf.tmpl`
- dev defaults: `dot_condarc`, `dot_clang-format`, selected config files

Oh My Zsh, Pure, zsh plugins, TPM 등 외부 dependency는 `.chezmoiexternal.toml`에 commit 기반으로 고정되어 있습니다.

확인:

```bash
just terminal-parity
```

API key 값은 git에 저장하지 않습니다. 완전한 terminal parity를 원하면 apply 전에 필요한 환경변수를 준비합니다.

```bash
export OPENAI_API_KEY="$(op read 'op://<vault>/<item>/<field>')"
export GOOGLE_API_KEY="$(op read 'op://<vault>/<item>/<field>')"
export POLLINATIONS_API_KEY="$(op read 'op://<vault>/<item>/<field>')"
```

## 안전장치와 중단 조건

최소 적용 전 확인:

```bash
scripts/verify-no-secrets.sh
just private-risk-audit
./bootstrap.sh --dry-run --tier cli
chezmoi diff --source .
```

멈춰야 하는 경우:

- secret scan 실패
- `chezmoi diff --source .`에 Keychain/browser session/token/cache/private key가 나타남
- `just private-risk-audit`의 HIGH 항목을 이해/수용하지 못함
- backup dry-run destination이 `/`, `$HOME`, repo root, marker 없는 drive로 나옴
- restore가 staging이 아니라 live home으로 직접 쓰려고 함
- macOS `full` dry-run에서 예상 밖의 app-state/database copy가 보임
- Ubuntu dry-run이 Ubuntu 외 distro logic으로 흐름

## Emergency external-drive backup

Repo는 외장 드라이브에도 clone/pull해서 sync합니다. 대용량 사용자 데이터는 repo 안이 아니라 외장 드라이브 root sibling directory에 둡니다.

```text
/Volumes/<EmergencyDrive>/
├── .workstation-backup-drive.json
├── workstation-bootstrap/        # this repo clone/pull
├── Desktop/
├── Documents/
├── Downloads/
├── Workspace/
├── Pictures/
├── Movies/
├── Music/
├── Public/
└── _backup-meta/
```

Dry-run:

```bash
just backup-plan DRIVE=/Volumes/<EmergencyDrive>
```

Apply:

```bash
just backup-apply DRIVE=/Volumes/<EmergencyDrive>
```

Restore는 live home이 아니라 staging이 기본입니다.

```bash
just restore-plan DRIVE=/Volumes/<EmergencyDrive>
scripts/restore-user-dirs.sh --drive /Volumes/<EmergencyDrive> --apply --destination ~/Restore-Staging/YYYYMMDD
```

자세한 내용: `docs/emergency-backup-layout.md`

## 주요 명령

```bash
just --list
just install
just doctor
just verify
just installer-smoke
just terminal-parity
just private-risk-audit
just public-audit
just manifest-check
just backup-smoke
just ubuntu-smoke
```

## Repo surface: 무엇이 필요한가?

요약:

- **핵심 유지:** `install.sh`, `bootstrap.sh`, `Justfile`, `packages/`, `scripts/install-*`, `scripts/verify-*`, `.chezmoi*`, terminal dotfiles, backup/restore scripts.
- **고급/정책 문서로 유지:** security/public/private/readiness/backup docs.
- **레거시이지만 당장 삭제하지 않음:** `masterplan.md`, `scripts/sanitize-import.sh`, `import-init*` recipes. Init provenance와 re-import 안전장치라 quick start에서는 숨기되 보존합니다.
- **미래 cleanup 후보:** Nix phase note, 너무 작은 platform docs, import-init tooling은 bootstrap이 실제 머신에서 충분히 검증된 뒤 archive/remove 여부 결정.

자세한 검토: `docs/repo-surface-review.md`

## Repo layout

- `install.sh` — interface-first first-run installer wrapper
- `bootstrap.sh` — deterministic bootstrap engine for automation/testing
- `packages/` — Homebrew, MAS, apt, VS Code, language-tool manifests
- `backup/` — user directory backup manifest/excludes
- `scripts/` — install/audit/backup/restore/verification scripts
- `.chezmoi*`, `dot_*`, `private_dot_*` — chezmoi source files
- `docs/` — platform, backup, security, verification, cleanup policy
- `masterplan.md` — historical Init v2 planning record, not the first-run guide
