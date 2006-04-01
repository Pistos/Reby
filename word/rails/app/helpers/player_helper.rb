module PlayerHelper
    def sort_link( label, column = label.downcase )
        extra_params = { :sort => column }
        if params[ :sort ] == column and params[ :reverse ].nil?
            extra_params[ :reverse ] = 'true'
        else
            extra_params[ :reverse ] = nil
        end
        link_to label, :overwrite_params => extra_params
    end
    
    def sorted_class( sortkey )
        retval = ''
        if params[ :sort ] == sortkey
            retval = 'class="sortkey"'
        end
        return retval
    end
end
