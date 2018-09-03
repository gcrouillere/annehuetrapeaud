ActiveAdmin.register Ceramique, as: 'Produits' do
  permit_params :name, :description, :stock, :weight, :category_id, :price_cents, :photo1, :photo2, :photo3, :photo4, :position
  menu priority: 1
  config.filters = false

  index do
    column :id
    column :position
    column :name
    column :description
    column :stock
    column :weight
    column "Catégorie" do |ceramique|
      ceramique.category.name
    end
    column :price_cents
    column "Nb de ventes - CA", :sortable => 'ceramique.basketlines.sum(:quantity)* ceramique.price' do |ceramique|
      "#{ceramique.basketlines.joins(:order).where.not("orders.state = ?", "lost").sum(:quantity)} - #{ceramique.basketlines.joins(:order).where.not("orders.state = ?", "lost").sum(:quantity) * ceramique.price} €"
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
      f.input :photo1, :as => :formtastic_attachinary, :hint => "Sélectionnez la photo1 du produit."
      f.input :photo2, :as => :formtastic_attachinary, :hint => "Sélectionnez la photo2 du produit."
      f.input :photo3, :as => :formtastic_attachinary, :hint => "Sélectionnez la photo3 du produit."
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
      span img(src: "http://res.cloudinary.com/#{ENV['CLOUDINARY_NAME']}/image/upload/#{ceramique.photo1.path}") if ceramique.photo1
      span img(src: "http://res.cloudinary.com/#{ENV['CLOUDINARY_NAME']}/image/upload/#{ceramique.photo2.path}") if ceramique.photo2
      span img(src: "http://res.cloudinary.com/#{ENV['CLOUDINARY_NAME']}/image/upload/#{ceramique.photo3.path}") if ceramique.photo3
      span img(src: "http://res.cloudinary.com/#{ENV['CLOUDINARY_NAME']}/image/upload/#{ceramique.photo4.path}") if ceramique.photo4
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
          flash[:notice] = "Produit mis à jour"
          redirect_to admin_produits_path and return
        else
          flash[:alert] = "Certains champs ont été oubliés ou ne sont pas correctement remplis. Voir ci-dessous."
        end
      end
    end

  end

end
