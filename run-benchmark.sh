#!/bin/bash

# Run the scikit-learn asv benchmark suite against master and commit the new
# result to https://github.com/scikit-learn/scikit-learn-benchmarks


# Add ssh key to be able to push to github
eval "$(ssh-agent -s)"
ssh-add ${HOME}/.ssh/sklbench
ssh-keyscan github.com >> ${HOME}/.ssh/known_hosts

# Config git
git config --global user.email "sklearn.benchmark.bot@gmail.com"
git config --global user.name "sklearn-benchmark-bot"

# Clone the sklearn-benchmark repo which stores the benchmark results and hosts
# the benchmarks website https://scikit-learn.github.io/scikit-learn-benchmarks/
git clone git@github.com:scikit-learn/scikit-learn-benchmarks.git

# Clone scikit-learn. The benchmark suite is the asv_benchmarks/ directory
git clone https://github.com/scikit-learn/scikit-learn.git

pushd scikit-learn/asv_benchmarks

# Get the short hash of the last commit
COMMIT_TO_BENCH=$(git rev-parse HEAD)
COMMIT_TO_BENCH=${COMMIT_TO_BENCH:0:8}

# Get all previous results to regenerate the html
if [[ -d ${HOME}/scikit-learn-benchmarks/results ]]; then
   cp -r ${HOME}/scikit-learn-benchmarks/results .
fi

# Install gcc
sudo apt-get install --assume-yes gcc
sudo apt-get install --assume-yes g++
sudo apt-get install --assume-yes make

# install Conda
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ${HOME}/miniconda.sh
bash ${HOME}/miniconda.sh -b -p ${HOME}/miniconda
PATH=${HOME}/miniconda/bin:${PATH}

# Create a conda env and install asv
conda create -y -n skl_benchmark python=3.8
source ${HOME}/miniconda/etc/profile.d/conda.sh
conda activate skl_benchmark
pip install git+https://github.com/airspeed-velocity/asv

# Create the .asv-machine.json file.
cat <<EOT >> ${HOME}/.asv-machine.json
{
    "sklearn-benchmark": {
        "arch": "x86_64",
        "cpu": "Intel Core Processor (Haswell, no TSX)",
        "machine": "sklearn-benchmark",
        "num_cpu": "8",
        "os": "Linux 4.15.0-20-generic",
        "ram": "16424684"
    },
    "version": 1
}
EOT

# Run the benchmarks
SKLBENCH_NJOBS=[1,4] asv run -e $COMMIT_TO_BENCH^!

# Generate html
asv publish

# Move to scikit-learn-benchmarks/ to commit the new result
popd
pushd scikit-learn-benchmarks/
cp -r ${HOME}/scikit-learn/asv_benchmarks/results/ .
git add .
git commit -m 'new result'
git push origin master

git checkout gh-pages
cp -r ${HOME}/scikit-learn/asv_benchmarks/html/* .
git add .
git commit -m 'new result'
git push origin gh-pages
