#!/bin/bash
set -eux

# Mount EFS
EFS_PATH=/home/ec2-user/SageMaker/efs
if [ ! -d "$EFS_PATH" ]; then
    mkdir -p "$EFS_PATH"
fi

_EFS_MOUNT_NFS_COMMAND_ $EFS_PATH
# e.g. sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-XXXXXX.efs.us-west-2.amazonaws.com:/ $EFS_PATH
sudo chmod go+rw $EFS_PATH

# Check scripts
SCRIPT_DIR=/home/ec2-user/SageMaker/lifecycle/scripts
if [ ! -d "$SCRIPT_DIR" ]; then
	mkdir -p $SCRIPT_DIR
	aws s3 sync _S3_SCRIPT_PATH_ $SCRIPT_DIR
fi

# Setup custom conda envs
sudo -u ec2-user -i << 'EOF'
unset SUDO_UID

WORKING_DIR=/home/ec2-user/SageMaker/custom-miniconda
source "$WORKING_DIR/miniconda/bin/activate"

for env in $WORKING_DIR/miniconda/envs/*; do
    BASENAME=$(basename "$env")
    source activate "$BASENAME"
    python -m ipykernel install --user --name "$BASENAME" --display-name "Custom ($BASENAME)"
    conda deactivate
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

# Setup CodeServer
bash $SCRIPT_DIR/setup-codeserver.sh
