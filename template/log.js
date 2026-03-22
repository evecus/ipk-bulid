'use strict';
'require fs';
'require poll';
'require uci';
'require view';

var logPath = '__LOG_PATH__';
var userScrolled = false;
var scrollPosition = 0;

return view.extend({
    render: function() {
        var logArea = E('textarea', {
            style: 'width:100%;height:500px;font-family:monospace;font-size:12px;',
            readonly: true,
            wrap: 'off',
        }, _('加载中...'));

        logArea.addEventListener('scroll', function() {
            userScrolled = true;
            scrollPosition = logArea.scrollTop;
        });

        poll.add(function() {
            return L.resolveDefault(fs.read_direct(logPath, 'text'), '').then(function(res) {
                var content = (res || '').trim() || _('暂无日志');
                logArea.value = content;
                if (!userScrolled) {
                    logArea.scrollTop = logArea.scrollHeight;
                } else {
                    logArea.scrollTop = scrollPosition;
                }
            });
        });

        var clearBtn = E('input', {
            class: 'btn cbi-button-action',
            type: 'button',
            value: _('清空日志'),
            click: function() {
                return L.resolveDefault(fs.write(logPath, ''), null).then(function() {
                    logArea.value = '';
                    userScrolled = false;
                });
            }
        });

        return E('div', { class: 'cbi-map' }, [
            E('div', { class: 'cbi-section' }, [
                E('div', { style: 'margin-bottom:8px' }, [ clearBtn ]),
                logArea,
            ])
        ]);
    },

    handleSave: null,
    handleSaveApply: null,
    handleReset: null,
});
