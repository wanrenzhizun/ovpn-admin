# ovpn-admin 

用于在 Linux 中管理 OpenVPN 用户、他们的证书和路由的简单 Web UI。后端是用 Go 编写的，而前端是基于 Vue.js 的。

最初在 [Flant](https:flant.com) 中创建用于内部需求并使用多年，然后更新为更现代和 [公开发布](https:blog.flant.comintroducing-ovpn-admin-web-interface-for -openvpn) 于 21 年 3 月。欢迎您的贡献！

免责声明！该项目是为有经验的用户（系统管理员）和私人（例如，受网络策略保护）环境创建的。因此，它的实现并没有考虑到安全性（例如，它没有严格检查用户传递的所有参数等）。 它还严重依赖文件，如果所需文件不可用，则会失败。

## 功能
- 添加 OpenVPN 用户（为他们生成证书）；
- 撤销恢复用户证书；生成可供用户使用的配置文件；
- 为 Prometheus 提供指标，包括证书到期日期、（connectedtotal）用户数、已连接用户信息； 
- （可选）为每个用户指定 CCD（`client-config-dir`）； 
- （可选）以主从模式运行（与其他服务器同步证书和 CCD）； 
- （可选）在 OpenVPN 中指定更改密码以进行额外授权； 
- （可选）指定 Kubernetes LoadBalancer 如果它在 OpenVPN 服务器前面使用（以在 `client.conf.tpl` 模板中获得自动定义的 `remote`）
- （可选）在Kubernetes Secrets中存储证书和其他文件(**注意，此功能是实验性的！**)。

### 截图
在 ovpn-admin 中管理用户的屏幕截图：

![ovpn-admin UI](img/ovpn-admin-users.png) 

使用 ovpn-admin 指标制作的仪表板示例：

![ovpn-admin metrics](img/ovpn-admin-metrics.png) 

## 安装
### 免责声明 
该工具使用外部调用`bash`、`coreutils` 和`easy-rsa`，因此目前仅支持Linux 系统。

### 1. Docker 

有一个现成的[docker-compose.yaml](https:github.comflantovpn-adminblobmasterdocker-compose.yaml)，所以你可以更改添加你需要的值，然后用[start.sh]( https:github.comflantovpn-adminblobmasterstart.sh)。

要求：您需要安装 [Docker](https:docs.docker.comget-docker) 和 [docker-compose](https:docs.docker.comcomposeinstall)。

要执行的命令：
```
bash git clone https//:github.com/flant/ovpn-admin.git 
cd ovpn-admin 
.start.sh 

``` 
### 2. 从源代码构建
   需求： 您需要安装了以下组件的 
   
Linux： - [golang](https:golang.orgdocinstall) - [packr2](https:github.comgobuffalopackrinstallation) - [nodejsnpm](https:nodejs.orgendownloadpackage-manager) 

要执行的命令：
```bash 
git clone https://github.com/flant/ovpn-admin.git 
cd ovpn-admin 
.bootstrap.sh 
.build.sh 
.ovpn-admin 
``` 
（请不要忘记提前配置所有需要的参数。） 
### 3. 预构建二进制文件 (WIP)

您还可以从 [releases](https://github.com/flant/ovpn-admin/releases) 页面下载和使用预构建的二进制文件 —— 只需选择一个相关的 tar.gz 文件。

要使用密码身份验证（`--auth` 标志），您必须安装 [openvpn-user](https:github.compashcovichopenvpn-userreleases)。
这个工具应该在你的 `PATH` 中可用，并且它的二进制文件应该是可执行的 (`+x`)。

## 用法 

``` 
用法：ovpn-admin [<flags>] 
Flags：

    --help                              显示上下文相关的帮助（也可以尝试 --help-long 和 --help-man）
    
    --listen.host="0.0.0.0"             ovpn-admin（或 $OVPN_LISTEN_HOST）的主机 
    
    --listen.port="8080"                ovpn-admin（或 $OVPN_LISTEN_PROT）的端口 
    
    --role="master"                     服务器角色，master或slave（或 $OVPN_ROLE） 
    
    --master.host="http://127.0.0.1"    主服务的URL（或 $OVPN_MASTER_HOST）
    
    --master.basic-auth.user=""         主服务器基本身份验证（或 $OVPN_MASTER_USER）的用户 
    
    --master.basic-auth.password=""     （或 $OVPN_MASTER_PASSWORD）主服务器基本身份验证的密码 
    
    --master.sync-frequency=600          以秒为单位的主主机数据同步频率（或 $OVPN_MASTER_SYNC_FREQUENCY） 
    
    --master.sync-token=TOKEN            主主机数据同步安全令牌（或 $OVPN_MASTER_TOKEN） 
    
    --ovpn.network="172.16.100.024"       (或 $OVPN_NETWORK) NETWORKMASK_PREFIX for OpenVPN server 
    
    --ovpn.server=HOST:PORT:PROTOCOL      (或 $OVPN_SERVER) openVpn服务器的 HOST:PORT:PROTOCOL  可以有多个值 
    
    --ovpn.server.behindLB                如果你 OpenVPN 服务器位于具有 LoadBalancer 类型的 Kubernetes（或 $OVPN_LB）服务上，您可以启用它
    
    --ovpn.service="openvpn-external"     （或 $OVPN_LB_SERVICE）具有 LoadBalancer 类型的 Kubernetes 服务的名称，如果您的 OpenVPN 服务器在它之后
    
    --mgmt= main=127.0.0.1:8989           （或 $OVPN_MGMT） ALIAS=HOST:PORT 用于 OpenVPN 服务器管理接口；可以有多个值
     
    --metrics.path="metrics"               URL 路径，用于公开收集的指标（或 $OVPN_METRICS_PATH） 
    
    --easyrsa.path=".easyrsa"              easyrsa 目录（或 $EASYRSA_PATH）的路径 
    
    --easyrsa.index-path=".easyrsapkiindex.txt"（或 $OVPN_INDEX_PATH）easyrsa 索引文件的路径 
    
    --ccd                                   启用客户端配置目录（或 $OVPN_CCD） 
    
    --ccd.path=".ccd"                       客户端配置目录（或 $OVPN_CCD_PATH）的路径 
      
    --ccd.setup-path="./setup"              服务端setup的路径
     (or $OVPN_SETUP_PATH)

    --templates.openvpn-tpl-path=""        自定义 openvpn.tpl 的路径
     (or $OVPN_TEMPLATES_OPENVPN_PATH)
  
    
    --templates.clientconfig-path=""        （或 $OVPN_TEMPLATES_CC_PATH）自定义 client.conf.tpl 的路径 
    
    --templates.ccd-path=""                 自定义 ccd.tpl（或 $OVPN_TEMPLATES_CCD_PATH）的路径 
    
    --auth.password                         启用额外的密码授权（或 $OVPN_AUTH) 
    
    --auth.db=".easyrsapkiusers.db"         (或 $OVPN_AUTH_DB_PATH) 密码授权的数据库路径 
    
    --debug                                 启用调试模式（或 $OVPN_DEBUG） 
    
    --verbose                               启用详细模式（或 $OVPN_VERBOSE） 
    
    --version                               显示应用程序版本

``` 

更多信息请随意使用[issues](https:github.comflantovpn-adminissues)和[discussions](https:github.comflantovpn-admindiscussions)来g来自维护者和社区的帮助。
