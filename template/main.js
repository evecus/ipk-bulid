'use strict';
'require form';
'require poll';
'require rpc';
'require uci';
'require view';

var callServiceList = rpc.declare({
    object: 'service',
    method: 'list',
    params: ['name'],
    expect: { '': {} }
});

function getServiceStatus() {
    return L.resolveDefault(callServiceList('__SERVICE__'), {}).then(function(res) {
        var isRunning = false;
        try {
            isRunning = res['__SERVICE__']['instances']['__SERVICE__']['running'];
        } catch(e) {}
        return isRunning;
    });
}

function renderStatus(isRunning) {
    var spanTemp = '<em><span style="color:%s"><strong>%s %s</strong></span></em>';
    var renderHTML;
    if (isRunning) {
        __OPEN_BTN__
        renderHTML = spanTemp.format('green', '__SERVICE__', _('运行中'))__OPEN_BTN_APPEND__;
    } else {
        renderHTML = spanTemp.format('red', '__SERVICE__', _('未运行'));
    }
    return renderHTML;
}

return view.extend({
    load: function() {
        return Promise.all([
            uci.load('__SERVICE__'),
            getServiceStatus(),
        ]);
    },

    render: function(data) {
        var isRunning = data[1];

        var m, s, o;
        m = new form.Map('__SERVICE__', '__SERVICE__', '__DESCRIPTION__');

        s = m.section(form.TypedSection);
        s.anonymous = true;
        s.addremove = false;
        s.render = function() {
            poll.add(function() {
                return getServiceStatus().then(function(running) {
                    var el = document.getElementById('_service_status');
                    if (el) el.innerHTML = renderStatus(running);
                });
            });
            return E('div', { class: 'cbi-section' }, [
                E('p', { id: '_service_status' }, renderStatus(isRunning))
            ]);
        };

        s = m.section(form.NamedSection, 'config', '__SERVICE__', '基本设置');
        s.anonymous = true;

        o = s.option(form.Flag, 'enabled', '启用');
        o.default = o.disabled;
        o.rmempty = false;

        __FORM_FIELDS__

        return m.render();
    },

    handleSaveApply: function(ev) {
        return this.handleSave(ev).then(function() {
            return L.resolveDefault(L.uci.apply());
        });
    },
    handleReset: null,
});
