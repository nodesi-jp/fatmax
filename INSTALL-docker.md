# ハブを Docker で動かす

**ハブ（画面と記録を集める1台）を Docker のコンテナで動かす**手順です。
中身は [apt で入れる](INSTALL.md) のと同じ `fatmax` パッケージで、Debian のコンテナに入れて動かすだけです。
systemd の無いマシンや、ホストに直接入れたくないときに使います。いま配っているのは `0.1.179` です。

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
# ほかのマシンから届く、このマシンの IP を同じフォルダの .env に書く
# Linux
echo "FATMAX_LAN_IP=$(ip route get 1.1.1.1 | awk '{for(i=1;i<NF;i++) if($i=="src") print $(i+1)}')" > .env
# macOS（Wi-Fi が en0 とは限らないので、既定の経路の口から引く）
echo "FATMAX_LAN_IP=$(ipconfig getifaddr "$(route -n get default | awk '/interface:/{print $2}')")" > .env

cat .env                     # FATMAX_LAN_IP=192.168.0.21 のように IP が入っていること
docker compose up -d --build
docker compose logs hub
```

**`export` ではなく `.env` に書く。** Compose はこのフォルダの `.env` を毎回読みます。
`export` だと、版を上げるときに別のシェルで叩いた `docker compose up -d --build` に渡らず、
**空のまま作り直されます**（エラーは出ません。下の注記の「渡し忘れ」と同じことになる）。
`TZ` と `FATMAX_PORT` も同じ `.env` に書けます。

Linux で `docker` に `sudo` が要るなら、`sudo docker compose …` でそのまま動きます（`.env` はファイルなので `sudo` でも読まれる）。

こう出れば動いています。初回は 20 秒ほどかかります。

```
fatmax hub  版 0.1.179 (…)
fatmax hub listening on https://0.0.0.0:8787/
  LAN:   https://192.168.0.21:8787/  (FATMAX_LAN_IP)
  画面:  https://192.168.0.21:8787/login?token=<トークン>
  指紋:  sha256//…
  setup: curl -fsSL -k --pinnedpubkey 'sha256//…' 'https://192.168.0.21:8787/setup.sh?t=<トークン>' | sh
  db:    /var/lib/fatmax/fatmax.db
```

画面は `https://<このマシンの IP>:8787/` です。**最初の1回はログの `画面:` の URL で開きます**
（トークンが入っているので、そのままログインできます。あとはブラウザが覚えます）。
通信は TLS で暗号化され、接続はトークンで認証されます。証明書はハブが自分で作ったものなので、
**ブラウザは最初に一度警告を出します**（消したいなら `https://<IP>:8787/ca.pem` を OS に信頼させる）。
それでも**インターネットへ直接は晒さないでください**（LAN の中だけ。外から使うなら VPN の内側に）。

トークン・指紋・導入の1行は、あとからでも出せます（ログが流れてしまったとき）:

```sh
docker compose exec hub fatmax token
```

| 渡すもの | 既定 | 意味 |
|---|---|---|
| `FATMAX_LAN_IP` | なし | **ほかのマシンから届く、このマシンの IP**。下の注記 |
| `TZ` | `Asia/Tokyo` | 日の境目。日別の金額・検索の「今日」・1日ぶんのタイムラインはこの土地の 0時で切る |
| `FATMAX_PORT` | `8787` | 外に出すポート（compose.yaml の左側だけ変わる）。**起動ログの `:8787` はコンテナの中の番号なので変わりません** —— 変えたら `setup:` の1行の URL のポートだけ書き換える（`'https://<IP>:<FATMAX_PORT>/setup.sh?t=<トークン>'`。setup.sh の中身は、取りに行ったポートで作られる） |

### rootless の Docker で動かすとき

起動はそのまま通りますが、**2つ足さないと使えません**。

```sh
# ① LAN から届くようにする（LAN の中だけ。暗号化と認証はあるが、外には開けない）
sudo ufw allow from 192.168.0.0/24 to any port 8787 proto tcp
# ② ログアウト・再起動で止めない
systemctl --user enable docker
sudo loginctl enable-linger $(whoami)
```

- **① ふつうの Docker は ufw を素通りしますが、rootless は通りません。** ふつうの Docker は自分で
  iptables に穴を開けます。rootless はふつうのプロセスとしてポートを開くので、ufw がそのまま効きます。
  症状は「ハブのマシンの中からは開けるのに、ほかのマシンからは**断られずに時間切れ**」です
  （ping も ssh も通るので、ネットワークの問題に見えます）
- **② rootless の Docker は、あなたのユーザの systemd で動いています。** ログアウトするとそれごと止まり、
  `restart: unless-stopped` も Docker 自体が動いていないと効きません
- 繋いできた相手の IP はハブに伝わりませんが、fatmax は使っていないので影響はありません

## 3. 各マシンを繋ぐ

ここから先は [install](INSTALL.md) と同じです。見たいマシンで、ログに出た `setup:` の1行を叩きます
（画面の「導入」にも、`docker compose exec hub fatmax token` にも同じ1行が出ます）。

```sh
curl -fsSL -k --pinnedpubkey '<指紋>' 'https://<このマシンの IP>:8787/setup.sh?t=<トークン>' | sh
```

`-k` は「証明書の発行元を問わない」、`--pinnedpubkey` は「でも鍵が指紋と違えば切る」です。
2つ揃って、このハブにだけ繋がります（名前ではなく鍵で照合するので、IP が動いても繋がる）。

**ハブを動かしているマシン自身の Claude Code も見るなら**、宛先を `127.0.0.1` にします。
公開したポートに届くので、DHCP で IP が動いても外れません（指紋は同じハブなので同じ）。

```sh
curl -fsSL -k --pinnedpubkey '<指紋>' 'https://127.0.0.1:8787/setup.sh?t=<トークン>' | sh -s -- --hub https://127.0.0.1:8787
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
  DHCP で IP が動いたら `.env` を書き直して `docker compose up -d`
- **時間帯を渡さないと、日の境目が朝 9時にずれます。** コンテナの既定は UTC です。
  日本以外なら `TZ=America/Los_Angeles docker compose up -d` のように渡します
- **ほかのマシンに配るウォッチャー**（setup.sh がパッケージの無いマシンに置くもの）は、
  macOS・Linux（amd64 / arm64）・Windows を入れてあります。Windows のマシンは
  [Windows で入れる](INSTALL-windows.md) の一式で入れるのが楽です
- 中では**パッケージが作る `fatmax` ユーザ**で動きます

## 今の DB を持って行く

ほかのマシンで動かしていたハブの記録を引き継ぐなら、**コンテナを最初に起動する前に**入れます。
2. の `.env` は書いておき、`docker compose up` の代わりに下の4行を叩きます。
DB がほかのマシンにあるなら、1行目はそのマシンで叩いて、できたファイルを `scp` でこちらへ運びます。

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
