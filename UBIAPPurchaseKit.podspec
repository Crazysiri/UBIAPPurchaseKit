

Pod::Spec.new do |s|

  s.name         = "UBIAPPurchaseKit"
  s.version      = "0.0.1"
  s.summary      = "UBIAPPurchaseKit iap 内购请求"
  s.description  = <<-DESC
	            Description:UBIAPPurchaseKit iap 内购请求...
                   DESC

  s.homepage     = "https://github.com/Crazysiri/UBIAPPurchaseKit.git"

   s.license          = { :type => 'MIT', :file => 'LICENSE' }

  s.author             = { "zero" => "511121933@qq.com" }

  s.source       = { :git => "https://github.com/Crazysiri/UBIAPPurchaseKit.git", :tag => "#{s.version}" }

   s.platform     = :ios, "9.0"


  s.source_files  = "UBIAPPurchaseKit/*.{h,m}"


end
