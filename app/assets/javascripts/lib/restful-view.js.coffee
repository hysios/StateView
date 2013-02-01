define ["jquery", "backbone", "lib/state-machine", "lib/state-view", 'exports'], ($, Backbone, StateMachine, StateView, exports) ->

    joinPath = (path, args...) ->
        paths = path.split '/'
        paths = paths.concat args
        paths.join '/'

    class MetaDataModel extends Backbone.Model

        constructor: (el, @options = {}) ->
            @el ||= el
            super(@options)
            @parse(@el)


        parse: (el) ->
            $(el).find("data").each (i, e) =>
                @set $(e).attr("meta"), $(e).text() || $(e).attr('value')

    class RESTfulRouter extends Backbone.Router

        constructor: (alias, @view, options) ->
            @routes ||= {}
            @routes[alias["new"]] = "newPage"
            @routes[":id/#{alias["edit"]}"] = "editPage"
            @routes[":id/#{alias["show"]}"] = "showPage"

            super(options)

        newPage: () ->
            @view.edit()

        editPage: (id) ->
            @view.edit()

        showPage: (id) ->
            @view.display()

    class ItemView extends StateView.AbstructStateView        

        modelAdapter: MetaDataModel

        display_new_callback: null #显示回调,参数: _html        

        as: {
            new: 'new'
            create: 'create'
            show: 'show'
            edit: 'edit'
            update: 'update'
            destroy: 'destroy'
        }

        states:
            initial: 'none'

            events:  [
                { name: 'display',  from: ['none', 'create', 'update'], to: 'show' }
                { name: 'editable', from: 'none',                       to: 'new' }
                { name: 'editable', from: 'show',                       to: 'edit' }
                { name: 'save',     from: 'new',                        to: 'create' }
                { name: 'save',     from: 'edit',                       to: 'update' }
                { name: 'back',     from: 'edit',                       to: 'show' }
                { name: 'back',     from: 'new',                        to: 'none'}
                { name: "back",     from: 'create',                     to: 'none' }
                { name: 'remove',   from: ['show', 'edit'],             to: 'destroy' }
            ]

            callbacks: 
                onenterstate: (event, from, to, msg) ->
                    console.log "event: #{event} from #{from} to #{to}"        
    
        constructor: (@options) ->          
            @tagName = @options.tag_name if @options.tag_name?
            @el = @options['el'] || @el                       
            super
            @model = @options['model'] || new @modelAdapter(@el)            
            @display_new_callback = @options.display_new_callback          
            @eventBoundder()
            # ItemView.router ||= new ItemView.routeAdapter(@as, @)
        
        eventBoundder: () ->
            @$("form").unbind("submit")
            @$("form").submit($.proxy(@submitForm, @))            
            @$("[state-transcation]").each((i, el) =>
                el = $(el)
                trigger_event = el.attr("state-event") || "click"
                el.on trigger_event, () =>                     
                    @eventTrigger el.attr("state-transcation")
                    false
            )            

        eventTrigger: (name) ->
            @[name].apply(@)

        beforeDisplay: (event, from, to, msg) ->            
            if from == 'update' || from == 'create'
                if msg?                
                    @renderHtml(msg)
            else
                @renderState(to)

        leaveNone: (event, from, to) ->
            if to == 'new'
                @renderState(to, () =>
                    @display_new_callback.call(@)
                )

        leaveShow: (event, from, to) ->
            if to == 'edit'
                @renderState('edit')

        beforeBack: (event, from , to ) ->
            @restoreState()

        leaveEdit: (event, from, to, msg) ->            
            if to == 'update'
                @$("form").append("<input name='_method' value='put' type='hidden' />")
                @postRequest('update')

        leaveNew: (event, from, to, msg) ->
            if to == 'create'                
                @postRequest('create')
        leaveCreate: (event, from, to, msg) ->
            @renderState(to, () =>                
                @display_new_callback.call(@)
            )                    

        postRequest: (state) ->
            url = @getStateUrl state                
            $.post( url, @$("form").serialize(), 
                (data, status, xhr) =>                                                                                   
                    @transition()                                                             
                    if state is "create"                   
                        @model.parse($("<div>").html(data))                        
                        @trigger("bind_new_view", { model: @model })                        
                        @back()                        
                    else 
                        @display(data)
                        @model.parse(@el)           

            ).error (event, status, msg) =>                 
                data = event.responseText
                @transition.cancel()                    
                @renderHtml(data)               

            StateMachine.ASYNC 
        submitForm: () ->       
            @save()
            false

        render: () ->
            @renderState(@current)
            @eventBoundder()

        renderState: (state, callback = (@el) -> ) ->
            url = @getStateUrl(state)
            if url?
                @backupHtml = $(@el).html()            
                $.ajax url, ajaxify: true, success: (data) =>                 
                    @renderHtml(data)      
                    @transition()
                    callback(@)

                StateMachine.ASYNC

        renderHtml: (html) ->                       
            $(@el).html html
            @eventBoundder()

        restoreState: () ->
            $(@el).html(@backupHtml)
            @eventBoundder()

        getStateUrl: (state) ->
            state_path = @as[state]
            switch state
                when 'new'
                    joinPath @urlRoot, state_path
                when 'create'
                    @urlRoot
                when 'edit'
                    joinPath @urlRoot, @model.get("id"), state_path
                when 'update', 'show', 'destroy'
                    joinPath @urlRoot, @model.get("id")             

    class CollectionView extends Backbone.View

        new_action_element: null

        itemAdapter: ItemView

        constructor: (@options = {}) ->                        
            @new_action_element = @options.new_action_element || @new_action_element
            @bind_new_event()      

        bind_new_event: () -> 
            if @new_action_element
                @new_action_element.bind("click", () =>
                    if !@new_view? || @new_view.current is "none"
                        @new_view = @bind_item_view(                        
                            initial: "none",
                            display_new_callback: @options.display_new_callback,
                            tag_name: @options.new_tag_name
                        )                                                        
                        @new_view.eventTrigger("editable")
                        @new_view.bind("bind_new_view", _.bind(@bind_new_view, @))
                    return false
                )
        bind_new_view: (options = {}) ->            
            _.extend(options, {
                initial: "create",
                display_new_callback: @options.render_new_callback 
            })
            new_view = @bind_item_view(options)
            new_view.display()

        bind_item_view: (options = {}) ->
            new @itemAdapter(options)




    exports.ItemView = ItemView
    exports.CollectionView = CollectionView
    exports