ActiveAdmin.register Ceramique, as: 'Produits' do
  permit_params :name, :description, :stock, :weight, :category_id, :price_cents, :photo1, :photo2, :photo3, :photo4, :position
  menu priority: 1
  config.filters = false
  config.sort_order = 'position_asc'

  index do
    span Category.all.map{|c| c.name}.join("#"), class: "hidden-categories"
    column :id
    column :position
    column :name
    column "Description" do |ceramique|
      ceramique.description.size > 200 ? etc = " ..." : etc = ""
      ceramique.description[0..200] + etc
    end
    column :stock
    column :weight
    column "Catégorie", class: "col-category" do |ceramique|
      ceramique.category.name
    end
    column :price_cents
    column "HIDDEN DESCRIPTION", class: "hidden-desc" do |ceramique|
      ceramique.description
    end
    actions
  end

  form do |f|
    f.inputs "" do
      f.input :name
      f.input :description
      f.input :position
      f.input :stock
      f.input :weight, :hint => "Poids en grammes"
      f.input :category
      f.input :price_cents, :hint => "Prix en centimes d'euros. Ex: entrez 1200 pour un prix de 12 €"
    end
    f.inputs "Images", class: 'product_images' do
      img(src: cl_image_path(f.object.photo1.path, :width=>250, :crop=>"scale")) unless (f.object.new_record? || f.object.photo1.blank?)
      f.input :photo1, :as => :formtastic_attachinary, :hint => "Sélectionnez la photo1 du produit."
      img(src: cl_image_path(f.object.photo2 .path, :width=>250, :crop=>"scale")) unless (f.object.new_record? || f.object.photo2.blank?)
      f.input :photo2, :as => :formtastic_attachinary, :hint => "Sélectionnez la photo2 du produit."
      img(src: cl_image_path(f.object.photo3 .path, :width=>250, :crop=>"scale")) unless (f.object.new_record? || f.object.photo3.blank?)
      f.input :photo3, :as => :formtastic_attachinary, :hint => "Sélectionnez la photo3 du produit."
      img(src: cl_image_path(f.object.photo4 .path, :width=>250, :crop=>"scale")) unless (f.object.new_record? || f.object.photo4.blank?)
      f.input :photo4, :as => :formtastic_attachinary, :hint => "Sélectionnez la photo4 du produit."
    end
    f.actions
  end

show do |ceramique|
  attributes_table do
    row :name
    row :description
    row :stock
    row :weight
    row "Categorie" do |ceramique|
      ceramique.category.name
    end
    row :price_cents
    row :images do |ceramique|
      span img(src: cl_image_path(ceramique.photo1&.path || "", :width=>250, :crop=>"scale")) if ceramique.photo1
      span img(src: cl_image_path(ceramique.photo2&.path || "", :width=>250, :crop=>"scale")) if ceramique.photo2
      span img(src: cl_image_path(ceramique.photo3.path, :width=>250, :crop=>"scale")) if ceramique.photo3
      span img(src: cl_image_path(ceramique.photo4.path, :width=>250, :crop=>"scale")) if ceramique.photo4
    end
  end
 end

 csv do
    column :position
    column :name
    column :description
    column :stock
    column :weight
    column "Catégorie" do |ceramique|
      ceramique.category.name
    end
    column :price_cents
    column "Nb de ventes - CA" do |ceramique|
      total = 0
      sum = 0
      ceramique.basketlines.each do |basketline|
        if basketline.order.state == "paid"
          total += basketline.quantity
        end
      end
      sum = total * ceramique.price
      "#{total} - #{sum} €"
    end
 end

  controller do

    def create
      super do |format|
        if resource.valid?
          flash[:notice] = "Produit créé"
          product_positions_management
          redirect_to admin_produits_path and return
        else
          flash[:alert] = "Certains champs ont été oubliés ou ne sont pas correctement remplis. Voir ci-dessous."
        end
      end
    end

    def destroy
      if Order.where(state: ["pending","payment page"]).joins(:basketlines).where("basketlines.ceramique_id = ?", resource.id).present?
        flash[:alert] = "Ce produit est dans un panier dans le processus d'achat, vous ne pouvez pas le supprimer"
        redirect_to request.referrer and return
      else
        resource.basketlines.update(ceramique_id: nil)
        flash[:notice] = "#{ENV['MODEL'][0...-1].capitalize} supprimé"
      end
      super do |format|
        redirect_to admin_produits_path and return
      end
    end

    def update
      super do |format|
        if resource.valid?
          product_positions_management
          flash[:notice] = "Produit mis à jour"
          redirect_to admin_produits_path and return
        else
          flash[:alert] = "Certains champs ont été oubliés ou ne sont pas correctement remplis. Voir ci-dessous."
        end
      end
    end

    def product_positions_management
      if params[:ceramique][:position].present?
        products_to_manage = Ceramique.where("position IS NOT NULL AND position >= ?", params[:ceramique][:position]).where.not(id: resource.id)
        products_to_manage.each {|product| product.update(position: product.position + 1)}
        new_ceramiques_order = Ceramique.all.order(position: :asc).order(updated_at: :desc)
        Ceramique.all.order(position: :asc).order(updated_at: :desc).each{|ceramique| ceramique.update(position: new_ceramiques_order.index(ceramique) + 1)}
      end
    end

  end

end
