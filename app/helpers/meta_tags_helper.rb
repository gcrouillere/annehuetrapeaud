module MetaTagsHelper
  def meta_title
    content_for?(:meta_title) ? content_for(:meta_title) : "Les #{ENV['MODEL']} de #{ENV['FIRSTNAME'].capitalize} Huet Rapeaud"
  end

  def meta_product_name
    content_for?(:meta_product_name) ? content_for(:meta_product_name) : "Les #{ENV['MODEL']} de #{ENV['FIRSTNAME'].capitalize} Huet Rapeaud - vente de produits de l'artisanat"
  end

  def meta_description
    description = "Des céramiques somptueuses. Venez découvrir leur fabrication lors d'un stage."
    content_for?(:meta_description) ? content_for(:meta_description) : description
  end

  def meta_image
    meta_image = (content_for?(:meta_image) ? content_for(:meta_image).strip : image_path(ENV['HOMEPIC']))
    # little twist to make it work equally with an asset or a url
    meta_image.starts_with?("http") ? meta_image : image_url(meta_image)
  end
end

