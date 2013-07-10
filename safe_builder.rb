#
# a replacement for Builder:XmlMarkup
#
# The SafeBuilder aims to work nice and easy with html_safe strings.
# It also adds some features in working with enumerables.
#
# First of all SafeBuilder is built upon the html_safe feature (hence it's name)
#
# It does automatically escape all strings that are not html_safe
# but it leaves all html_safe strings untouched.
#
# SafeBuilder also adds some new features.
# It accepts Enumerables as content
#
# Project Goals
# - provide a new implementation of Builder
# - be fully html_safe aware
# - be compatible with Builder:XmlMarkup as much as possible within the other goals
# - add new features
#
# New Features
# - should not break compatibility
# -- except where the beahviour for Builder:XmlMarkup was not well defined
# -- or if adds substantial value for cases not usually found in existing code
#
# SafeBuilder aims to work quite well as a drop-in replacement for Builder
# for normal use Scenarios.
# While your mileage may vary if you've used Builder in some interesting ways
#
#
#

require 'active_support'    # need this for html_safe support

class SafeBuilder < BasicObject    
    
    # options:
    # selfclose:true        allow self closing tags
    # namespace:namespace   prepend namespace to all generated tags
    # indent:false          indent generated tags for easier reading,
    # currently only inserts newlines, should allow an integer for the number of spaces
    def initialize options=nil
        @buffer     = ::ActiveSupport::SafeBuffer.new
        unless options.nil?
            @options    = options.dup
            @namespace  = @options.delete(:namespace)
            @selfclose  = @options.delete(:selfclose)   || true
            @indent     = @options.delete(:indent)      || true
            @compatible = @options.delete(:compatible)  || false
        end
    end
    
    
    # returns buffer
    def to_s
        return @buffer
    end
    def to_str
        return @buffer
    end

    def html_safe?
        true
    end
    
    # append arg to buffer
    def << arg
        @buffer << arg
    end

    # compatibility with Builder:XmlMarkup, deprecated
    def text! text
        @buffer << text
    end
    
    # compatibility with Builder:XmlMarkup, deprecated
    def target!
        @buffer
    end
    
    def tag! tag, *args, &block
        self.method_missing(tag, *args, &block)
    end


    # tag                   -> string
    # tag(content)          -> string
    # tag(options)          -> string
    # tag(content, options) -> string
    # tag(options) {block}  -> string
    # tag(content, options) {block}  -> string
    # options:
    # options are inherited from the initialization of the SafeBuilder
    # see there for a description and for the defaults
    #   :selfclose
    #   :namespace
    #   :indent
    # all other options are rendered as attributes of the generated tag
    # use a string key to force rendering an option as an attribute 
    #
    # New features (incompatible)
    #
    # if the block returns a string (and if it's not the builders buffer)
    # it is rendered as the content of the tag
    # so you now can do something like
    # html.div{"foo"} instead of html.div{html.text! "foo"}
    # TODO: maybe we should extend this to enumerables, could make for some new tricks
    #
    # Enumerables as content:
    #
    # if content is enumerable and no block is given,
    # tag is rendered for each element of content
    #
    # if content is enumerable and block is given 
    # tag is rendered once and block is called with every enumerable
    # 
    # Examples
    #   div [1,2] -> <div>1</div><div>2</div>
    #
    # not implemented, yet:
    #   ul [1,2] {|b,x|b.li x} => <div><li>1</li><li>2</li></div>
    #
    # Future enhancement:
    #   when the block returns an enumerable
    #   then the tag should be rendered for every item returned
    #
    # Future enhancement:
    #   what should we do if the content or the result of the block is actually a lambda?
    #   there might be some cool tricks that could be achieved with that
    #
    def method_missing tag, *args, &block
        content = (args[0].kind_of? ::Hash) ? nil : args.shift
        options = (args[0].kind_of? ::Hash)   ? args.shift : nil
        unless options.nil?
            namespace   = options.delete(:namespace)|| @namespace
            selfclose   = options.delete(:selfclose)|| @selfclose
            indent      = options.delete(:indent)   || @indent
            compatible  = options.delete(:compatible)
        end
        tag     = namespace+':'+tag.to_s if namespace
        
        enumerable = content.respond_to?(:each) ? content : [content]
        
        (::Kernel.block_given? && [1] || enumerable).each do |text|
            # create start tag
            @buffer.safe_concat "<#{tag}"
            
            # append options if any
            unless options.nil?
                options.each do |k,v|
                    @buffer << " #{k}"
                    unless v.nil?   # use nil value for no value
                        @buffer.safe_concat '='
                        @buffer.safe_concat v.to_s.encode(:xml=>:attr)
                    end
                end
            end
            @buffer.safe_concat '>' # close the tag for now, content may come
            length  = @buffer.length
            
            if ::Kernel.block_given?
                enumerable.each do |text|
                    result  = yield self
                    # Builder::XMlMarkup does completely ignore the result of the block
                    # we use it as the elements content if it is a string other than ourselves
                    @buffer << result if result != @buffer and result.kind_of? ::String
                end
                else
                @buffer << text.to_s           
            end

            # close the tag
            if selfclose and length == @buffer.length
                # nothing appended: replace the '>' by a self closing tag
                @buffer[length-1]   = "/>"
                else
                @buffer.safe_concat "</#{tag}>"
            end
            @buffer.safe_concat "\n" if indent
        end
        return @buffer
    end
end


