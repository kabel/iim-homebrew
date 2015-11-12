require File.expand_path("../../Abstract/abstract-php-extension", __FILE__)

class Php70Sphinx < AbstractPhp70Extension
  init
  homepage "https://pecl.php.net/package/sphinx"
  head "https://git.php.net/repository/pecl/search_engine/sphinx.git", :branch => "php7"

  depends_on "pkg-config" => :build
  depends_on "libsphinxclient"

  def install
    Dir.chdir "sphinx-#{version}" unless build.head?

    ENV.universal_binary if build.universal?

    safe_phpize
    system "./configure", "--prefix=#{prefix}",
                          phpconfig,
                          "--with-sphinx=#{Formula["libsphinxclient"].opt_prefix}"
    system "make"
    prefix.install "modules/sphinx.so"
    write_config_file if build.with? "config-file"
  end
end
