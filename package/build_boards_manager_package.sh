#!/bin/bash

# Figure out how will the package be called
ver=`git describe --tags --always`

package_name=cuteduino-$ver
echo "Version: $ver"
echo "Package name: $package_name"

if [ "$TRAVIS_REPO_SLUG" = "" ]; then
TRAVIS_REPO_SLUG=bengchet/Cuteduino
fi
echo "Repo: $TRAVIS_REPO_SLUG"

PKG_URL=https://github.com/$TRAVIS_REPO_SLUG/releases/download/$ver/$package_name.zip
DOC_URL=https://forum.cytron.io/

# Create directory for the package
outdir=package/versions/$ver/$package_name
srcdir=$PWD
rm -rf package/versions/$ver
mkdir -p $outdir

# Some files should be excluded from the package
cat << EOF > exclude.txt
.git
.gitignore
.travis.yml
package
doc
EOF
# Also include all files which are ignored by git
git ls-files --other --directory >> exclude.txt
# Now copy files to $outdir
rsync -a --exclude-from 'exclude.txt' $srcdir/ $outdir/
rm exclude.txt

pushd package/versions/$ver
echo "Making $package_name.zip"
zip -qr $package_name.zip $package_name
rm -rf $package_name

# Calculate SHA sum and size
sha=`shasum -a 256 $package_name.zip | cut -f 1 -d ' '`
size=`/bin/ls -l $package_name.zip | awk '{print $5}'`
echo Size: $size
echo SHA-256: $sha

# Download latest package_cuteduino_index.json
old_json=package_cuteduino_index_stable.json 

if [ -e $srcdir/package_cuteduino_index.json ]; then
cat $srcdir/package_cuteduino_index.json > $old_json
else
cat $srcdir/package/package_cuteduino_index.template.json > $old_json
fi

new_json=package_cuteduino_index.json

echo "Making package_cytron_makeruno_index.json"
cat $srcdir/package/package_cuteduino_index.template.json | \
jq ".packages[0].platforms[0].version = \"$ver\" | \
    .packages[0].platforms[0].url = \"$PKG_URL\" |\
    .packages[0].platforms[0].archiveFileName = \"$package_name.zip\" |\
    .packages[0].platforms[0].checksum = \"SHA-256:$sha\" |\
    .packages[0].platforms[0].size = \"$size\" |\
    .packages[0].platforms[0].help.online = \"$DOC_URL\"" \
    > $new_json

set +e
if [ -e $srcdir/package_cuteduino_index.json ]; then
python ../../merge_packages.py $new_json $old_json >tmp && mv tmp $new_json && rm $old_json
else
rm $old_json
fi

# deploy key
echo -n $DEPLOY_KEY > ~/.ssh/deploy_b64
base64 --decode --ignore-garbage ~/.ssh/deploy_b64 > ~/.ssh/deploy
chmod 600 ~/.ssh/deploy
echo -e "Host $DEPLOY_HOST_NAME\n\tHostname github.com\n\tUser $DEPLOY_USER_NAME\n\tStrictHostKeyChecking no\n\tIdentityFile ~/.ssh/deploy" >> ~/.ssh/config

#update package_cytron_makeruno_index.json
git clone $DEPLOY_USER_NAME@$DEPLOY_HOST_NAME:$TRAVIS_REPO_SLUG.git ~/tmp
cp $new_json ~/tmp/
