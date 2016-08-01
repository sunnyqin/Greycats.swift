Pod::Spec.new do |s|
  s.name             = "Greycats"
  s.version          = "2.7.0"
  s.summary          = "A set of tools we use to speed up developing in greycats"
  s.description      = <<-DESC
						Currently includes
						* a TableViewData which binds Section to DataSource
						* a Filter which applies regexp search on UISearchBar | UITextField
						* AutolayoutStack
            * Customizable NavigationViewController
                       DESC
  s.homepage         = "http://github.com/greycats/Greycats.swift"
  s.license          = 'MIT'
  s.author           = { "Rex Sheng" => "shengning@gmail.com" }
  s.source           = { :git => "https://github.com/greycats/Greycats.swift.git", :tag => s.version.to_s }
  s.requires_arc     = true
  s.platform         = :ios, "8.0"

  s.default_subspecs = %w[Core Layout Graphics]

  s.subspec "Core" do |s|
    s.source_files = "Greycats/{Graphics/Graphics,Core/*,Layout/Designable}.swift"
  end

  s.subspec "Layout" do |s|
    s.source_files = "Greycats/Layout/*.swift"
  end

  s.subspec "Graphics" do |s|
    s.source_files = "Greycats/Graphics/*.swift"
  end

  s.subspec "Geocode" do |s|
    s.source_files = "Greycats/Geocode.swift"
  end

  s.subspec "NavigationViewController" do |s|
    s.source_files = "Greycats/NavigationViewController.swift"
  end

  s.subspec "Camera" do |s|
    s.dependency "Greycats/Graphics"
    s.source_files = "Greycats/Camera.swift"
  end

  s.subspec "Filter" do |s|
    s.dependency "Greycats/Layout"
    s.source_files = "Greycats/Filter.swift"
  end

  s.subspec "Breadcrumb" do |s|
    s.source_files = "Greycats/Breadcrumb.swift"
  end

end
