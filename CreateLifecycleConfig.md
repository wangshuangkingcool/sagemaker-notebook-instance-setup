# SageMaker Notebook Instance Setup

## Create Lifecycle Config using API

通过运行AWS SDK CLI创建SageMaker Lifecycle Configuration for Notebook Instance。以下样例的创建和启动实例脚本包括：
* 创建efs目录，并在启动时挂载EFS文件系统（实例启动后文件夹会始终存在，但EFS挂载会在每次停止实例后失效，再次启动时需要重新挂载）
* 创建/配置自定义Conda 环境并安装软件包（Conda env安装在EBS卷中，停止实例后不会消失，再次启动需要重新配置配置并将内核注册到 Jupyter 中）
* 安装/配置CodeServer

### 1. 创建S3桶并上传scripts
* 以管理员身份登录AWS Console，并打开CloudShell服务
> **_INFO:_** CloudShell只在部分区域，请选择一个距离当地最近的区域。在调用API时我们将通过`--region`来指定区域。
* 下载CodeServer脚本, 将脚本上传到S3

```
cd /tmp
curl -LO https://github.com/aws-samples/amazon-sagemaker-codeserver/releases/download/v0.1.5/amazon-sagemaker-codeserver-0.1.5.tar.gz
tar -xvzf amazon-sagemaker-codeserver-0.1.5.tar.gz
```

```
BUCKET_NAME=<intended bucket name>
SCRIPT_PATH=s3://$BUCKET_NAME/lifecycle/scripts
REGION=ap-southeast-1

aws s3api create-bucket --bucket $BUCKET_NAME --create-bucket-configuration LocationConstraint=$REGION --region $REGION
aws s3 sync /tmp/amazon-sagemaker-codeserver/install-scripts/notebook-instances/ $SCRIPT_PATH --region $REGION
```

### 2.创建EFS文件系统

* 参考 [SharedStorage](/SharedStorage.md)
* 进入EFS控制台，选择要挂载文件系统获取文件系统，点击链接，复制NFS命令行

```
NFS_MOUNT="sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-xxxxxxx.efs.ap-southeast-1.amazonaws.com:/"
```

> **_INFO:_** 删除命令结尾的efs，只保留到`<dns>.efs.<region>.amazonaws.com:/`

### 3. 更新脚本

```
curl -LO https://raw.githubusercontent.com/wangshuangkingcool/sagemaker-notebook-instance-setup/md/static/scripts/oncreate_s3.sh
curl -LO https://raw.githubusercontent.com/wangshuangkingcool/sagemaker-notebook-instance-setup/md/static/scripts/onstart_s3.sh

sed -i "s|_S3_SCRIPT_PATH_|$SCRIPT_PATH|g" oncreate_s3.sh
sed -i "s|_S3_SCRIPT_PATH_|$SCRIPT_PATH|g" onstart_s3.sh
sed -i "s|_EFS_MOUNT_NFS_COMMAND_|$NFS_MOUNT|g" onstart_s3.sh
```

### 4. 创建Lifecycle Configuration
```
aws sagemaker create-notebook-instance-lifecycle-config \
    --notebook-instance-lifecycle-config-name instance-setup-lifecycle-v1 \
    --on-start Content="$((cat onstart_s3.sh || echo "")| base64)" \
    --on-create Content="$((cat oncreate_s3.sh || echo "")| base64)" \
    --region $REGION
```