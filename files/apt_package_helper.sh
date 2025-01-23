
get_valid_apt_packages() {
    local packages=($1)
    local valid_packages=()

    for package in ${packages[@]}; do
        apt-cache search "^$package$"
        if apt-cache search "^$package$" > /dev/null 2>&1; then
            valid_packages+=("$package")
        fi
    done

    echo "${valid_packages[@]}"
}

get_valid_apt_packages vim poopy python3-opae.pacsign
