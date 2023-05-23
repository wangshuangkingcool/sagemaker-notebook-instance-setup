#!/bin/bash
set -eux

# Create EFS directory
EFS_PATH=/home/ec2-user/SageMaker/efs
sudo mkdir -p $EFS_PATH

sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-0ed540c51d6b94f4f.efs.us-west-2.amazonaws.com:/ $EFS_PATH
sudo chmod go+rw $EFS_PATH

# Fetch all scripts
SCRIPT_DIR=/home/ec2-user/SageMaker/lifecycle/scripts
mkdir -p $SCRIPT_DIR
aws s3 sync s3://sagemaker-lifecycles-917168543081/notebook $SCRIPT_DIR

# Install conda on EBS
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

KERNEL_NAMES="chatgpt chatglm"
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

EOF

# Install CodeServer
bash $SCRIPT_DIR/install-codeserver.sh