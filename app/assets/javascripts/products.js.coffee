# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/


define ['jquery', 'backbone', 'lib/restful-view'], ($, Backbone, RESTfulView) ->

    class ProductRowView extends RESTfulView.ItemView

        urlRoot: "/products"


        # enterEdit: (event) ->
        #   alert "edit"

        beforeBack: (event, from ,to) ->
            if confirm("really quit editor?")
                super
            else 
                false

    class ProductView extends Backbone.View

        add_row : (options) ->
            new ProductRowView(options)


