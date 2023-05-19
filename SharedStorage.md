# SageMaker Notebook Instance Setup

## Shared Storage

SageMaker notebook instances拥有相互独立的存储（EBS），如需访问共享数据：

* 将数据保存在S3，并从多个实例调用AWS SDK访问S3
* 为实例挂在同一个EFS文件系统，即可访问共享目录

Reference：https://aws.amazon.com/blogs/machine-learning/mount-an-efs-file-system-to-an-amazon-sagemaker-notebook-with-lifecycle-configurations/

### Steps

* 前往AWS控制台，进入EFS服务，创建文件系统
* 创建完成后，点击文件系统，点击“Attach“（连接），复制“通过DNS挂载 - 使用 NFS 客户端” 命令行
* 连接需要挂在共享文件系统的实例（需要与文件系统处于同一VPC内），打开terminal

```
cd SageMaker && mkdir efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-xxxxxx.efs.us-west-2.amazonaws.com:/ efs
`sudo chmod go``+``rw ``./``efs`
```

* 可创建文件保存到efs目录中，在其他挂载该文件系统的实例上可查看该文件
* 创建Lifecycle configuration，使实例在创建和启动时完成efs挂载
    * on-start

    ```
    #!/bin/bash
    set -e

    # Attach EFS for sharing
    EFS_PATH=/home/ec2-user/SageMaker/efs
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-00c91d768ba5538b5.efs.us-west-2.amazonaws.com:/ $EFS_PATH
    sudo chmod go+rw $EFS_PATH
    ```
    * on-create

    ```
    #!/bin/bash
    set -e

    # Create EFS directory for sharing
    sudo mkdir /home/ec2-user/SageMaker/efs
    ```