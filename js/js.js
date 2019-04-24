$(function () {

    function inv (c) {
        return c == 'none' ? 'table-row' : 'none'
    }

    $('img').each (function () {
    
        var $this = $(this)
        var $tr = $this.closest ('tr')
        var end = $tr.attr ('class').replace ('start', 'end')
    
        $this.css ({cursor: 'pointer'}).click (function () {
        
            var $t = $tr.next ()

            while ($t.length && $t.attr ('class') != end) {
                $t.css ({display: inv ($t.css ('display'))})
                $t = $t.next ()
            }

        })
        
    })
    
    var max = 1
    
    $('tr').each (function () {
    
        var c = $(this).attr ('class')
        if (!c) return
        
        var m = c.match (/roup(\d+)/)
        if (!m) return
        
        var n = m [1]
        if (max < n) max = n
        
    })
    
    var $div = $('<div style="position:fixed;top:0;padding:10px;">').prependTo ($('body'))
    
    for (var i = 1; i <= max; i ++) {
        $('<button>')
            .text (i)
            .click (function (e) {
            
                var $b = $(e.target)
                
                $('button').css ({background: 'buttonface'})
                $b.css ({background: '#ffffdd'})
            
                var l = parseInt ($b.text ())
            
                $('tr').each (function () {

                    var c = $(this).attr ('class')
                    if (!c) return

                    var m = c.match (/roup(\d+)/)
                    if (!m) return
                    
                    var n = m [1]
                    
                    $(this).css ({display: n > l ? 'none' : 'table-row'})
    
                })

            })
            .appendTo ($div)
    }

})