if [ -z "$1" ]; then
  echo "Usage: $0 <filename>"
  exit 1
fi

filename=$1
hexo new "$filename"
echo "New blog post created: $filename"

cd source/Asset
mkdir "$filename"
cd "$filename"
touch .gitkeep
cd ../../..
