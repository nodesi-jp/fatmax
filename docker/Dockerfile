# syntax=docker/dockerfile:1
#
# fatmax のハブを Docker で動かす。**中身は公開の apt リポジトリの fatmax です**
# （INSTALL.md の `apt install fatmax` と同じもの。ソースからは作りません）。
#
#   この Dockerfile と compose.yaml を同じフォルダに置いて:
#   docker compose up -d --build
#
# 手順と注意: https://nodesi-jp.github.io/fatmax/INSTALL-docker.md
# 新しい版が出たら、同じ1行で上がります（下の「版が出たら作り直す」）。
# 記録は /var/lib/fatmax/fatmax.db（パッケージの置き場所のまま）。
# **ボリュームを付けないとコンテナを消したときに消えます**（compose.yaml は付けてある）。
#
# ここで決めていること（理由も書いておく）:
#
# - **時間帯は `TZ`（既定 Asia/Tokyo）。** 日別の集計は「その土地の 0時」で切っていて、
#   SQLite の `localtime` が `TZ` を読む。コンテナの既定は UTC なので、
#   **渡さないと日の境目が朝 9時にずれる**（金額も検索の「今日」も1日ぶんのタイムラインも）
# - **`FATMAX_LAN_IP`。** コンテナの中からは、ほかのマシンから届く IP が引けない。
#   詳しくは compose.yaml
# - **PID 1 は tini。** ハブは SIGTERM を自分で拾わないので、PID 1 のままだと
#   `docker stop` が 10 秒待ってから殺すことになる
# - **記録の置き場の持ち主で動く**（`fatmax-entrypoint`）。持ち主は書き換えない

FROM debian:trixie-slim

# dist.conf の APT_URL と同じであること（build-apt.sh が配る前に確かめる）。
ARG APT_URL=https://nodesi-jp.github.io/fatmax

# **版が出たら作り直す。** `apt-get install` の層はキャッシュされるので、そのままだと
# `--build` しても**黙って古い版のまま**になる。BuildKit は ADD の URL を毎回見に行き、
# 中身が変わったときだけ、ここから下を作り直す。apt の索引（Release）は版を出すたびに
# 変わるので、それを合図にする。
ADD ${APT_URL}/dists/stable/Release /etc/fatmax-apt-release

# INSTALL.md の apt の3行と同じ（sudo を外しただけ）。
# tzdata: TZ を読むため。tini: PID 1。curl: 鍵を取る・ヘルスチェック。
# パッケージは入れても何も起動しない（postinst は fatmax ユーザと /var/lib/fatmax を作るだけ）。
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl tini tzdata \
 && curl -fsSL "$APT_URL/KEY.gpg" -o /usr/share/keyrings/fatmax.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] $APT_URL stable main" \
      > /etc/apt/sources.list.d/fatmax.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends fatmax \
 && rm -rf /var/lib/apt/lists/* \
 && fatmax --version

# **ほかのマシンに配るウォッチャー。** setup.sh は、パッケージの無いマシン（macOS・コンテナ）に
# ハブからウォッチャーを落とす（`/watch/bin/<種類>`）。ハブ自身の CPU のぶんは自分を配るが、
# 他は手元に置いていないと 404 になり、そのマシンは**1件も記録されない**。
# 公開リポジトリの bin/ から取り、SHA256SUMS で確かめる（切れた本文を配らない）。
# 自分の CPU のぶんは要らないので取らない。
RUN mkdir -p /opt/fatmax/dist \
 && cd /opt/fatmax/dist \
 && curl -fsSL -O "$APT_URL/bin/SHA256SUMS" \
 && self="fatmax-linux-$(uname -m)" \
 && grep -v " $self\$" SHA256SUMS > want \
 && for f in $(awk '{print $2}' want); do curl -fsSL -O "$APT_URL/bin/$f"; done \
 && sha256sum -c want \
 && chmod 755 fatmax-* \
 && rm SHA256SUMS want \
 && ls -l

# **記録の置き場の持ち主で動かす。**
#
# 名前付きボリュームなら持ち主はパッケージが作った fatmax ユーザ。手元のフォルダを
# マウントしたなら、そのフォルダの持ち主で動く。**`chown -R` で揃えない** ——
# 手元の ~/.fatmax をそのままマウントした人のファイルまで持ち主が変わり、
# コンテナの外の fatmax が書けなくなる。
#
# **揃えるのは fatmax.db* だけ、ずれているときだけ。** `docker cp` で入れた DB は
# 手元の持ち主のまま入る（実測: uid 501 の DB が fatmax のフォルダに置かれた）。
# DB の持ち主で動くと、今度はフォルダに -wal / -shm を作れず
# `attempt to write a readonly database` で起動しない。どちらに合わせても片方に書けないので、
# フォルダに合わせる。ずれていなければ1つも触らない。
#
# **`--db` は必ずここで足す。** 既定は ~/.fatmax/fatmax.db で、引数を変えただけ
# （`hub --port 9000`）で記録がボリュームの外へ出て、**作り直したときに消える**。
COPY --chmod=755 <<'EOF' /usr/local/bin/fatmax-entrypoint
#!/bin/sh
set -eu
data=/var/lib/fatmax
if [ "${1:-}" = hub ]; then
  case " $* " in
    *" --db "*) ;;
    *) set -- "$@" --db "$data/fatmax.db" ;;
  esac
fi
if [ "$(id -u)" = 0 ]; then
  owner=$(stat -c %u:%g "$data")
  for f in "$data/fatmax.db" "$data/fatmax.db-wal" "$data/fatmax.db-shm"; do
    if [ -e "$f" ] && [ "$(stat -c %u:%g "$f")" != "$owner" ]; then
      echo "fatmax-entrypoint: $f の持ち主を $data に揃えます ($(stat -c %u:%g "$f") -> $owner)" >&2
      chown "$owner" "$f"
    fi
  done
  if [ "${owner%%:*}" != 0 ]; then
    export HOME="$data"
    exec setpriv --reuid="${owner%%:*}" --regid="${owner##*:}" --clear-groups fatmax "$@"
  fi
fi
exec fatmax "$@"
EOF

ENV TZ=Asia/Tokyo \
    FATMAX_DIST=/opt/fatmax/dist
WORKDIR /var/lib/fatmax
VOLUME /var/lib/fatmax
EXPOSE 8787
# /healthz は版と件数を返すだけ（COUNT(*) が5つ）。30 秒に1回なら気にならない。
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS -o /dev/null http://127.0.0.1:8787/healthz || exit 1
ENTRYPOINT ["/usr/bin/tini", "--", "fatmax-entrypoint"]
CMD ["hub"]
