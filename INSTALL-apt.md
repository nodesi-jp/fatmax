# apt で入れる（Ubuntu / Debian）

Ubuntu・Debian（WSL の Ubuntu を含む）に **apt で入れる**手順です。いま配っているのは `0.1.166` です。
CPU（amd64 / arm64）は apt が選びます。署名済みです。

入れるものは1つ（`fatmax` パッケージ）で、**入れたマシンの役目は次のどちらか**です。

| 役目 | すること | 台数 |
|---|---|---|
| **ハブ** | 画面と記録を集める | **LAN に1台** |
| **見たいマシン** | そのマシンの Claude Code の記録をハブへ送る（ウォッチャー） | 何台でも |

1台でハブと見たいマシンを兼ねても構いません（下の「ハブのマシン自身も見る」）。

- dnf のディストリ（Amazon Linux / Fedora / RHEL） → **[dnf で入れる](INSTALL-dnf.md)**
- ハブを Docker で動かす → **[Docker で動かす](INSTALL-docker.md)**
- Windows → **[Windows で入れる](INSTALL-windows.md)**

## 1. パッケージを入れる（どちらの役目でも同じ）

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/KEY.gpg | sudo tee /usr/share/keyrings/fatmax.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://nodesi-jp.github.io/fatmax stable main" | sudo tee /etc/apt/sources.list.d/fatmax.list
sudo apt update && sudo apt install fatmax
fatmax --version
```

**入れただけでは何も動きません。** 役目に合わせて 2. のどちらかへ進みます。

## 2a. ハブにする

```sh
sudo systemctl enable --now fatmax-hub
```

`https://<このマシンの IP>:8787/` が開けば動いています。記録は `/var/lib/fatmax/fatmax.db` です。

**最初の1回はトークンが要ります。** トークン・指紋・導入の1行はこれで出ます:

```sh
sudo -u fatmax fatmax token --db /var/lib/fatmax/fatmax.db
```

出てきた `画面:` の URL で開けばそのままログインできます（あとはブラウザが覚えます）。
証明書はハブが自分で作ったものなので、ブラウザは最初に一度警告を出します
（消したいなら `https://<IP>:8787/ca.pem` を OS に信頼させる）。

- 通信は TLS で暗号化され、接続はトークンで認証されます。それでも**インターネットへ直接は晒さないでください**（LAN の中だけ。外から使うなら VPN の内側に）
- **ハブは LAN に1台だけ**にします。見たいだけのマシンでこの1行を叩くと、ハブがもう1つ立ちます
- ハブが配るウォッチャーの実行ファイルは、**このマシンと同じ CPU のぶんだけ**です。
  Mac や Windows も繋ぐなら、[Docker で動かしたハブ](INSTALL-docker.md)のほうが楽です（全部配れます）

## 2b. 見たいマシンにする

**Claude Code を開いているフォルダで**叩きます（入れ直しのときに二重登録を外せるのが、そのフォルダの下だけのため）。

```sh
# ハブに届くか
curl -fsSk -m 5 -o /dev/null https://<ハブの IP>:8787/healthz && echo 届く

# hook・OTel・宛先・指紋・トークンを入れる（パッケージの fatmax をそのまま使う）
# この1行はハブの画面の「導入」に出ています（ハブのマシンでは fatmax token でも出る）
curl -fsSL -k --pinnedpubkey '<指紋>' 'https://<ハブの IP>:8787/setup.sh?t=<トークン>' | sh

# ウォッチャーを動かす
nohup fatmax watch > /tmp/fatmax-watch.log 2>&1 &
fatmax status
```

終わったら **Claude Code を開き直してください**（OTel の設定は起動時にしか読まれません）。

`-k` は「証明書の発行元を問わない」、`--pinnedpubkey` は「でも鍵が指紋と違えば切る」です。
2つ揃って、このハブにだけ繋がります（名前ではなく鍵で照合するので、IP が動いても繋がる）。

- **ウォッチャーを動かさないと、記録はハブへ上がりません。** 消えはしません ——
  `~/.fatmax/spool` に溜まっていて、動かせばまとめて流れます
- **ウォッチャーはログアウト・再起動で止まります**（自分では立ち上がりません）。
  止まったら `nohup` の行を叩き直してください
- 画面に出る名前を決めるなら `echo '開発機' > ~/.claude/fatmax-host`（送るたびに読み直すので、再起動は要りません）
- 画面から返信したい・トークルームに本体で入れたいなら、`fatmax watch --replies` で動かします。
  **受けると、ハブの画面を開ける人（トークンを持つ人）なら誰でもこのマシンの Claude に依頼を送れます**。
  詳しくは [画面から返信する](INSTALL.md#画面から返信する任意)

### ハブのマシン自身も見る

宛先を `127.0.0.1` にします。DHCP で IP が動いても外れません。

```sh
curl -fsSL -k --pinnedpubkey '<指紋>' 'https://127.0.0.1:8787/setup.sh?t=<トークン>' | sh -s -- --hub https://127.0.0.1:8787
nohup fatmax watch > /tmp/fatmax-watch.log 2>&1 &
```

### sudo の無い root のコンテナ

devcontainer などで、プロンプトが `root@<英数字>:/workspaces#` の形のときです。**`sudo` を外す**のと、**名前を付ける**のが違いです。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/KEY.gpg -o /usr/share/keyrings/fatmax.gpg
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://nodesi-jp.github.io/fatmax stable main" > /etc/apt/sources.list.d/fatmax.list
apt update && apt install -y fatmax

mkdir -p ~/.claude && echo 'dev-linux' > ~/.claude/fatmax-host
curl -fsSL -k --pinnedpubkey '<指紋>' 'https://<ハブの IP>:8787/setup.sh?t=<トークン>' | sh
nohup fatmax watch > /tmp/fatmax-watch.log 2>&1 &
```

- **名前を付けないと、コンテナを作り直すたびに別のマシンとして出ます**（hostname がコンテナの ID になるため）
- コンテナの中から、ホスト側で動いているハブへは `https://host.docker.internal:8787` で届きます（1行の URL をそこだけ書き換える。指紋は同じ）
- 作り直す（Rebuild）と全部消えるので、もう一度叩いてください

## 新しい版に上げる

```sh
sudo apt update && sudo apt install --only-upgrade fatmax
fatmax --version
```

**入れ替わるのはファイルだけです。** 動いているものは前の版のままなので、動かし直します。

```sh
sudo systemctl restart fatmax-hub                                              # ハブ
pkill -f 'fatmax watch'; nohup fatmax watch > /tmp/fatmax-watch.log 2>&1 &     # 見たいマシン
fatmax status
```

動かし直し忘れていると、`fatmax status` が「再起動していません」と知らせます。
**ハブとウォッチャーの版は揃えてください**（片方だけ古いと、欠けた機能が黙って動きません）。

## 外す

見たいマシン（Claude Code を開いているフォルダで）:

```sh
curl -fsSL -k --pinnedpubkey '<指紋>' 'https://<ハブの IP>:8787/setup.sh?t=<トークン>' | sh -s -- --uninstall
pkill -f 'fatmax watch'
```

`settings.json` から fatmax が入れたものだけを外します。あなた自身の設定は残ります。

パッケージごと外す:

```sh
sudo systemctl disable --now fatmax-hub     # ハブにしていたら
sudo apt purge fatmax
sudo rm /etc/apt/sources.list.d/fatmax.list /usr/share/keyrings/fatmax.gpg
```

**記録は消えません**（`purge` でも残します）。消すなら自分で `sudo rm -rf /var/lib/fatmax`。

---

[README に戻る](README.md) ／ [詳しい説明（install）](INSTALL.md)
