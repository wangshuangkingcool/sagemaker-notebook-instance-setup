# SageMaker Notebook Instance Setup

## Persist Conda Env on EBS

将Conda安装在笔记本实例的EBS卷上，并通过conda/pip安装包，可以在实例停止后仍然保留安装和配置，无需再通过lifecycle configuration oncreate脚本安装

样例脚本：https://github.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples/tree/master/scripts/persistent-conda-ebs

### 创建Conda env & 安装包

* on-reate

```
#!/bin/bash

set -e

# OVERVIEW
# This script installs a custom, persistent installation of conda on the Notebook Instance's EBS volume, and ensures
# that these custom environments are available as kernels in Jupyter.
# 
# The on-create script downloads and installs a custom conda installation to the EBS volume via Miniconda. Any relevant
# packages can be installed here.
#   1. ipykernel is installed to ensure that the custom environment can be used as a Jupyter kernel   
#   2. Ensure the Notebook Instance has internet connectivity to download the Miniconda installer

sudo -u ec2-user -i <<'EOF'
unset SUDO_UID

# Install a separate conda installation via Miniconda
WORKING_DIR=/home/ec2-user/SageMaker/custom-miniconda
mkdir -p "$WORKING_DIR"
wget https://repo.anaconda.com/miniconda/Miniconda3-4.6.14-Linux-x86_64.sh -O "$WORKING_DIR/miniconda.sh"
bash "$WORKING_DIR/miniconda.sh" -b -u -p "$WORKING_DIR/miniconda" 
rm -rf "$WORKING_DIR/miniconda.sh"


# Create a custom conda environment
source "$WORKING_DIR/miniconda/bin/activate"
KERNEL_NAME="chatgpt"
PYTHON="3.9"

conda create --yes --name "$KERNEL_NAME" python="$PYTHON"
conda activate "$KERNEL_NAME"

pip install --quiet ipykernel

# Customize these lines as necessary to install the required packages
# conda install --yes numpy
# pip install --quiet boto3

for package in langchain==0.0.158 openai==0.27.5 python-dotenv==1.0.0 fastapi==0.95.1 uvicorn[standard]==0.22.0 websockets==11.0.2 Jinja2==3.1.2 faiss-cpu
do
    echo "Installing $package..."
    pip install --upgrade $package
done

EOF
```

* on-start

```
#!/bin/bash

set -e

# OVERVIEW
# This script installs a custom, persistent installation of conda on the Notebook Instance's EBS volume, and ensures
# that these custom environments are available as kernels in Jupyter.
# 
# The on-start script uses the custom conda environment created in the on-create script and uses the ipykernel package
# to add that as a kernel in Jupyter.
#
# For another example, see:
# https://docs.aws.amazon.com/sagemaker/latest/dg/nbi-add-external.html#nbi-isolated-environment

sudo -u ec2-user -i <<'EOF'
unset SUDO_UID

WORKING_DIR=/home/ec2-user/SageMaker/custom-miniconda
source "$WORKING_DIR/miniconda/bin/activate"

for env in $WORKING_DIR/miniconda/envs/*; do
    BASENAME=$(basename "$env")
    source activate "$BASENAME"
    python -m ipykernel install --user --name "$BASENAME" --display-name "Custom ($BASENAME)"
done

# Optionally, uncomment these lines to disable SageMaker-provided Conda functionality.
# echo "c.EnvironmentKernelSpecManager.use_conda_directly = False" >> /home/ec2-user/.jupyter/jupyter_notebook_config.py
# rm /home/ec2-user/.condarc
EOF

echo "Restarting the Jupyter server.."
# restart command is dependent on current running Amazon Linux and JupyterLab
CURR_VERSION=$(cat /etc/os-release)
if [[ $CURR_VERSION == *$"http://aws.amazon.com/amazon-linux-ami/"* ]]; then
	sudo initctl restart jupyter-server --no-wait
else
	sudo systemctl --no-block restart jupyter-server.service
fi
```

* Alternative on-create: 使用anaconda 创建多个env，在多个env中安装包
    * on-start 需要对目录做相应改动

```
#!/bin/bash

set -e

# OVERVIEW
# This script installs a custom, persistent installation of conda on the Notebook Instance's EBS volume, and ensures
# that these custom environments are available as kernels in Jupyter.
# 
# The on-create script downloads and installs a custom conda installation to the EBS volume via Miniconda. Any relevant
# packages can be installed here.
#   1. ipykernel is installed to ensure that the custom environment can be used as a Jupyter kernel   


sudo -u ec2-user -i <<'EOF'
unset SUDO_UID

# Install a separate conda installation via anaconda
WORKING_DIR=/home/ec2-user/SageMaker/custom-conda
mkdir -p "$WORKING_DIR"

# Create a custom conda environment
KERNEL_NAMES="chatgpt hello"
PYTHON="3.9"

for kernel in $KERNEL_NAMES
do
    conda create --yes --prefix "$WORKING_DIR/$kernel" python="$PYTHON"
    conda activate $WORKING_DIR/$kernel
    for package in ipykernel langchain==0.0.158 openai==0.27.5 python-dotenv==1.0.0 fastapi==0.95.1 uvicorn[standard]==0.22.0 websockets==11.0.2 Jinja2==3.1.2 faiss-cpu
    do
        echo "Installing $package..."
        pip install --quiet --upgrade $package
    done
done

EOF
```