VERSIONS=("4.0.1" "4.0.2" "3.3.0")

select VERSION in "${VERSIONS[@]}"; do
  if [[ -n "$VERSION" ]]; then
    break
  else
    echo "Invalid selection"
  fi
done

echo "You chose: $VERSION"
RUBY_CONFIGURE_OPTS="--disable-install-doc" rbenv install "$VERSION"
