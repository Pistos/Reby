module PlayerHelper
    def sort_link( label, column = label.downcase )
        retval = "<a href=\"?sort=#{column}"
        if params[ :sort ] == column and params[ :reverse ].nil?
            retval << '&reverse=true'
        end
        retval << "\">#{label}</a>"
    end
    
    def sorted_class( sortkey )
        retval = ''
        if params[ :sort ] == sortkey
            retval = 'class="sortkey"'
        end
        return retval
    end
end
