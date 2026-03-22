'use strict';
'require view';
'require form';
'require rpc';
'require poll';
'require uci';

const callGetStatus = rpc.declare({
    object: 'luci.{{SERVICE_NAME}}',
    method: 'get_status',
    expect: { '': {} }
});

return view.extend({
    load: function() {
        return uci.load('{{SERVICE_NAME}}');
    },

    render: function() {
        let m, s, o;
        m = new form.Map('{{SERVICE_NAME}}', '{{SERVICE_TITLE}}', '{{DESCRIPTION}}');

        // ── 状态栏 ────────────────────────────────────────
        const statusSection = m.section(form.TypedSection);
        statusSection.render = function() {
            const statusEl = E('span', {
                'style': 'font-style:italic; font-weight:bold;'
            }, '检查中...');

{{OPEN_BTN_DEF}}
            poll.add(function() {
                return callGetStatus().then(function(res) {
                    const running = res && res.running;
                    statusEl.innerHTML = running
                        ? '<span style="color:#27ae60; font-style:italic; font-weight:bold;">{{SERVICE_TITLE}} 运行中</span>'
                        : '<span style="color:#e74c3c; font-style:italic; font-weight:bold;">{{SERVICE_TITLE}} 未运行</span>';
                });
            }, 5);

            return E('div', { 'class': 'cbi-section', 'style': 'padding:8px 0;' }, [
                E('div', { 'style': 'display:flex; align-items:center;' }, [
                    statusEl{{OPEN_BTN_REF}}
                ])
            ]);
        };

        // ── 基本设置 ──────────────────────────────────────
        s = m.section(form.NamedSection, 'main', '{{SERVICE_NAME}}', '基本设置');
        s.anonymous = true;
        s.addremove = false;

        o = s.option(form.Flag, 'enabled', '启用');
        o.default = o.disabled;
        o.rmempty = false;

{{EXTRA_FIELDS}}
        return m.render();
    }
});
