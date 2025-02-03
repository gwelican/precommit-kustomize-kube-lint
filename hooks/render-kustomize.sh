#!/bin/bash
# Create results directory if it doesn't exist
#
results=$(mktemp)
echo $results

# Find changed yaml/yml files and get their parent directories
changed_dirs=$(git status --porcelain | grep -E '\.(yaml|yml)$' | awk '{print $2}' | xargs -I {} dirname {} | sort -u)
printf "Changed directories:\n$changed_dirs\n"

# Process each directory
for dir in $changed_dirs; do
    echo "Processing directory: $dir"
    
    # Check if kustomization file exists (supporting both yaml and yml)
    if [ -f "$dir/kustomization.yaml" ] || [ -f "$dir/kustomization.yml" ]; then
        echo "Rendering manifests with kustomize..."

        # Create a temporary file for rendered output
        temp_file=$(mktemp)

        # Render the manifests
        if kustomize build --enable-helm --enable-alpha-plugins "$dir" > "$temp_file"; then
            echo "Running kube-linter on rendered manifests..."

            # Run kube-linter and store output, but use its exit code
            if ! ~/bin/kube-linter lint "$temp_file" --format=plain >> $results; then
                echo "Linting issues found. Check results/kube-linter.txt for details."
                cat $results
                rm "$temp_file"
                exit 1
            fi

            # Clean up
            rm "$temp_file"
        else
            echo "Error: Failed to render manifests for $dir"
            rm "$temp_file"
            continue
        fi
    else
        echo "Skipping $dir - no kustomization file found"
    fi
    rm -rf $results
done

echo "No linting issues found."
exit 0
