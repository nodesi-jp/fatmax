# ハブを Docker で動かす

**ハブ（画面と記録を集める1台）を Docker のコンテナで動かす**手順です。
中身は [apt で入れる](INSTALL.md) のと同じ `fatmax` パッケージで、Debian のコンテナに入れて動かすだけです。
systemd の無いマシンや、ホストに直接入れたくないときに使います。いま配っているのは `0.1.144` です。

- コンテナの中で Claude Code を動かしていて、そのコンテナだけ見たい → **[コンテナ1つで完結](INSTALL-container.md)**
- Docker を使わない入れ方 → **[install](INSTALL.md)**

**要るのは Docker（Compose 付き）だけです。** Docker Desktop でも、Linux の Docker Engine でも動きます。
CPU は amd64 / arm64 のどちらでも、apt が選びます。

## 1. ファイルを2つ置く

```sh
mkdir fatmax-hub && cd fatmax-hub
curl -fsSLO https://nodesi-jp.github.io/fatmax/docker/Dockerfile
curl -fsSLO https://nodesi-jp.github.io/fatmax/docker/compose.yaml
```

| ファイル | 中身 |
|---|---|
| `Dockerfile` | Debian に apt で `fatmax` を入れる。ほかのマシンに配るウォッチャーも、このサイトの `bin/` から入れて `SHA256SUMS` で確かめる |
| `compose.yaml` | ポート・時間帯・記録の置き場まで決めてある。動かすときはこちらを使う |

## 2. 起動する

```sh
# ほかのマシンから届く、このマシンの IP を渡す
# macOS（Wi-Fi が en0 とは限らないので、既定の経路の口から引く）
export FATMAX_LAN_IP=$(ipconfig getifaddr "$(route -n get default | awk '/interface:/{print $2}')")
# Linux
export FATMAX_LAN_IP=$(ip route get 1.1.1.1 | awk '{for(i=1;i<NF;i++) if($i=="src") print $(i+1)}')

docker compose up -d --build
docker compose logs hub
```

こう出れば動いています。初回は 20 秒ほどかかります。

```
fatmax hub  版 0.1.144 (…)
fatmax hub listening on http://0.0.0.0:8787/
  LAN:   http://192.168.0.21:8787/  (FATMAX_LAN_IP)
  setup: curl -fsSL http://192.168.0.21:8787/setup.sh | sh
  db:    /var/lib/fatmax/fatmax.db
```

画面は `http://<このマシンの IP>:8787/` です。**認証はありません。** LAN の外に出さないでください。

| 渡すもの | 既定 | 意味 |
|---|---|---|
| `FATMAX_LAN_IP` | なし | **ほかのマシンから届く、このマシンの IP**。下の注記 |
| `TZ` | `Asia/Tokyo` | 日の境目。日別の金額・検索の「今日」・1日ぶんのタイムラインはこの土地の 0時で切る |
| `FATMAX_PORT` | `8787` | 外に出すポート（compose.yaml の左側だけ変わる） |

## 3. 各マシンを繋ぐ

ここから先は [install](INSTALL.md) と同じです。見たいマシンで、ログに出た `setup:` の1行を叩きます。

```sh
curl -fsSL http://<このマシンの IP>:8787/setup.sh | sh
```

**ハブを動かしているマシン自身の Claude Code も見るなら**、宛先を `127.0.0.1` にします。
公開したポートに届くので、DHCP で IP が動いても外れません。

```sh
curl -fsSL http://127.0.0.1:8787/setup.sh | sh -s -- --hub http://127.0.0.1:8787
```

## 新しい版に上げる

**起動と同じ1行です。** 1. のファイルを取り直す必要はありません。

```sh
docker compose up -d --build
```

新しい版が出ていれば入れ直し、出ていなければ何もしません（apt の索引が変わったときだけ作り直します）。
記録はボリュームにあるので残ります。上がった版は `docker compose logs hub` の1行目に出ます。

## 注意

- **記録はボリューム `fatmax_data` の `/var/lib/fatmax/fatmax.db`**（apt で入れたときと同じ置き場所）。
  作り直しても `docker compose down` しても残ります。**`docker compose down -v` は記録ごと消します**
- **`FATMAX_LAN_IP` を渡す理由。** コンテナの中からは、ほかのマシンから届く IP が引けません
  （引けるのはコンテナ自身の `172.x.x.x`）。使われるのは **localhost で画面を開いたときに setup.sh へ
  入る宛先**と起動時の案内だけで、LAN の IP で開けばそちらがそのまま使われます。
  渡し忘れると、localhost から取った setup.sh に**コンテナの IP が入って届きません**。
  **読めない値なら起動を断ります**（打ち間違いで黙ってコンテナの IP に落ちるのが一番困るため）。
  DHCP で IP が動いたら渡し直して `docker compose up -d`
- **時間帯を渡さないと、日の境目が朝 9時にずれます。** コンテナの既定は UTC です。
  日本以外なら `TZ=America/Los_Angeles docker compose up -d` のように渡します
- **ほかのマシンに配るウォッチャー**（setup.sh がパッケージの無いマシンに置くもの）は、
  macOS と Linux（amd64 / arm64）を入れてあります。Windows のぶんはありません（apt で入れたハブと同じ）
- 中では**パッケージが作る `fatmax` ユーザ**で動きます

## 今の DB を持って行く

ほかのマシンで動かしていたハブの記録を引き継ぐなら、**コンテナを最初に起動する前に**入れます。

```sh
sqlite3 ~/.fatmax/fatmax.db ".backup /tmp/fatmax-copy.db"   # 動いているハブのままでよい（1つのファイルに固まる）
docker compose create --build hub                            # 作るだけで起動しない
docker compose cp /tmp/fatmax-copy.db hub:/var/lib/fatmax/fatmax.db
docker compose start hub
```

- **`cp ~/.fatmax/fatmax.db` で直に写さない。** 書いたばかりのぶんは隣の `fatmax.db-wal` に居て、
  本体だけ写すとそこが抜けます。`.backup` なら1つのファイルに固まります
- **一度起動したあとに入れない。** ボリュームには空の DB の `fatmax.db-wal` が残っていて、
  入れた DB に**別の DB の WAL が当たります**。起動してしまったら `docker compose down -v`
  （ボリュームごと消す。中の記録も消えます）からやり直します
- 持ち主は起動時に揃えます（`docker compose cp` は手元の持ち主のまま入れるため）

## やめる

```sh
docker compose down          # 止める。記録は残る
docker compose down -v       # 記録（ボリューム）ごと消す
```

各マシンに入れた hook を外すのは [アンインストール](INSTALL.md#アンインストールuninstall) です。
