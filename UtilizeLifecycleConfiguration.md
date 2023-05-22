# SageMaker Notebook Instance Setup

## Lifecycle Configuration
使用Lifecycle Configuration在创建/启动笔记本实例/Studio时自动运行脚本，可用于安装、配置应用和管理实例生命周期等。

更多样例脚本可参考：https://github.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples/tree/master

### 安装多个pip package：on-start

```
#!/bin/bash

PACKAGES="numpy plotly"

for package in $PACKAGES; do
    echo "Installing $package..."
    pip install $package
done
```