#need to manually map *.tcz.* files to skip *.tcz.zsync and md5
wget -O- https://github.com/hjson/hjson-go/releases/download/v4.4.0/hjson_v4.4.0_linux_amd64.tar.gz | sudo tar -xz -C /usr/local/bin
rsync -av --size-only --delete --prune-empty-dirs --include="*/*/tcz/*.tcz.dep" --include="*/*/tcz/*.tcz.list" --include="*/*/tcz/*.tcz.info" --include="*/*/tcz/*.tcz.tree" --include="*/" --exclude="*" repo.tinycorelinux.net::tc ./tinycorelinux
result=$(rsync -av --list-only --include="*/*/tcz/*.tcz" --include="*/" --exclude="*" repo.tinycorelinux.net::tc ./tinycorelinux | grep '\.tcz')
echo "Finished getting file list"
providesTime=0
sizeTime=0
tagsTime=0
for version_dir in tinycorelinux/*.x; do
	version=$(basename "$version_dir")
	for arch_dir in tinycorelinux/$version/*; do
		arch=$(basename "$arch_dir")
		mkdir -p data/$version/$arch/
  		output_directory="data/$version/$arch"
		find tinycorelinux/$version/$arch/tcz/*.list -maxdepth 1 -type f -exec basename {} \; | sed 's/\.list//' > "$output_directory/tczlist"

  		start=$(date +%s);
		echo "{" > "$output_directory/provides"
		for file in tinycorelinux/$version/$arch/tcz/*.list; do
		    name=$(basename "$file" .list)
		    echo "\"$name\": [" >> "$output_directory/provides"
		    while IFS= read -r line || [ -n "$line" ]; do
		        echo "\"$line\"," >> "$output_directory/provides"
		    done < "$file"
		    echo "]," >> "$output_directory/provides"
		done
		echo "}" >> "$output_directory/provides"
		end=$(date +%s);
  		runtime=$((end-start))
  		providesTime=$((providesTime + runtime))
    
    		start=$(date +%s);
		echo "{" > "$output_directory/taglist"
		for file in tinycorelinux/$version/$arch/tcz/*.info; do
		    name=$(basename "$file" .info)
		    tags=$(grep -Eo 'Tags:[[:space:]]+.+' "$file" | awk '{$1=""; print $0}' | tr -s ' ' | sed 's/^[[:space:]]//')
		    echo "\"$name\": [\"$tags\"]," >> "$output_directory/taglist"
		done
		echo "}" >> "$output_directory/taglist"
  		end=$(date +%s);
  		runtime=$((end-start))
  		tagsTime=$((tagsTime + runtime))
  		echo "Finished $version - $arch"
 	done
done

echo "{" > "site-data/versions"
for version in ./data/*/; do
    version_name=$(basename "$version")
    echo "\"$version_name\": [" >> "site-data/versions"
    for arch in "$version"/*/; do
        arch_name=$(basename "$arch")
        echo "\"$arch_name\"," >> "site-data/versions"
    done
    echo "]," >> "site-data/versions"
done
echo "}" >> "site-data/versions"

#Sizelist json
start=$(date +%s);
for version_dir in tinycorelinux/*.x; do
	version=$(basename "$version_dir")
	for arch_dir in tinycorelinux/$version/*; do
		arch=$(basename "$arch_dir")
  		echo '{' > "data/$version/$arch/sizelist.json"
	done
done
 
IFS=$'\n'; for line in $result; do
    version=$(echo "$line" | awk '{print $5}' | cut -d '/' -f 1)
    arch=$(echo "$line" | awk '{print $5}' | cut -d '/' -f 2)
    file=$(echo "$line" | awk '{print $5}' | cut -d '/' -f 4)
    size=$(echo $line | awk '{gsub(",", ""); print $2}')
    echo "\"$file\":$size," >> "data/$version/$arch/sizelist.json"
done

for version_dir in tinycorelinux/*.x; do
	version=$(basename "$version_dir")
	for arch_dir in tinycorelinux/$version/*; do
		arch=$(basename "$arch_dir")
  		echo '}' >> "data/$version/$arch/sizelist.json"
    		sed -i ':begin;$!N;s/,\n}/\n}/g;tbegin;P;D' "data/$version/$arch/sizelist.json"
	done
done

end=$(date +%s);
runtime=$((end-start))
sizeTime=$((sizeTime + runtime))


for version_dir in tinycorelinux/*.x; do
	version=$(basename "$version_dir")
	for arch_dir in tinycorelinux/$version/*; do
		arch=$(basename "$arch_dir")
  		mv "data/$version/$arch/sizelist.json" "data/$version/$arch/sizelist.json.old"
  		hjson -j "data/$version/$arch/sizelist.json.old" > "data/$version/$arch/sizelist.json"
    		rm -rf "data/$version/$arch/sizelist.json.old"
  		hjson -j "data/$version/$arch/taglist" > "data/$version/$arch/taglist.json"
  		hjson -j "data/$version/$arch/provides" > "data/$version/$arch/provides.json"
	done
done
hjson -j site-data/versions > site-data/versions.json

echo provides: $providesTime
echo size: $sizeTime
echo tags: $tagsTime
git config --global user.name 'GitHub Actions'
git config --global user.email 'actions@github.com'
git add .
git commit -m "Update"
git push
