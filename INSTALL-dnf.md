# dnf で入れる（Amazon Linux 2023 / Fedora / RHEL）

Amazon Linux 2023・Fedora・RHEL 系に **dnf で入れる**手順です。いま配っているのは `0.1.166` です。
CPU（x86_64 / aarch64）は dnf が選びます。rpm と索引（repomd.xml）の両方に署名があります。

入れるものは1つ（`fatmax` パッケージ）で、**入れたマシンの役目は次のどちらか**です。

| 役目 | すること | 台数 |
|---|---|---|
| **ハブ** | 画面と記録を集める | **LAN に1台** |
| **見たいマシン** | そのマシンの Claude Code の記録をハブへ送る（ウォッチャー） | 何台でも |

- apt のディストリ（Ubuntu / Debian） → **[apt で入れる](INSTALL-apt.md)**
- ハブを Docker で動かす → **[Docker で動かす](INSTALL-docker.md)**
- Windows → **[Windows で入れる](INSTALL-windows.md)**

## 1. パッケージを入れる（どちらの役目でも同じ）

```sh
sudo curl -fsSL https://nodesi-jp.github.io/fatmax/dnf/fatmax.repo -o /etc/yum.repos.d/fatmax.repo
sudo dnf install fatmax
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

- 通信は TLS で暗号化され、接続はトークンで認証されます。それでも**インターネットへ直接は晒さないでください**。EC2 ならセキュリティグループで 8787 を自分の範囲だけに
- **ハブは LAN に1台だけ**にします。見たいだけのマシンでこの1行を叩くと、ハブがもう1つ立ちます
- firewalld が動いているなら `sudo firewall-cmd --add-port=8787/tcp --permanent && sudo firewall-cmd --reload`
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
- EC2 のコンテナから手元のハブへ SSH で繋ぐ構成は [複数 EC2 × 複数コンテナ](INSTALL-ec2.md)

### sudo の無い root のコンテナ

`sudo` を外して叩きます。**名前も付けてください**（付けないと、作り直すたびに別のマシンとして出ます）。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/dnf/fatmax.repo -o /etc/yum.repos.d/fatmax.repo
dnf install -y fatmax

mkdir -p ~/.claude && echo 'dev-linux' > ~/.claude/fatmax-host
curl -fsSL -k --pinnedpubkey '<指紋>' 'https://<ハブの IP>:8787/setup.sh?t=<トークン>' | sh
nohup fatmax watch > /tmp/fatmax-watch.log 2>&1 &
```

## 新しい版に上げる

**`dnf install` では上がりません。** 入っていると `Nothing to do.` `Complete!` と出て、
成功したように見えて何も変わりません。`upgrade` を使い、索引の取り直し（`--refresh`）も付けます
（dnf は索引をしばらく手元に置くので、付けないと新しい版が見えないことがあります）。

```sh
sudo dnf upgrade --refresh fatmax
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
sudo dnf remove fatmax
sudo rm /etc/yum.repos.d/fatmax.repo
```

**記録は消えません。** 消すなら自分で `sudo rm -rf /var/lib/fatmax`。

---

[README に戻る](README.md) ／ [詳しい説明（install）](INSTALL.md)
