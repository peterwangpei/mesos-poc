# ca.crt  kubecfg.crt  kubecfg.key

{% set file_list = ['ca.crt', 'kubecfg.crt', 'kubecfg.key'] %}

{% if grains['roles'] is defined and grains['roles'][0] == 'kubernetes-master' %}
{% set file_list = ['ca.crt', 'kubecfg.crt', 'kubecfg.key', 'server.cert', 'server.key'] %}
{% endif %}


{% for file in file_list %}

/srv/kubernetes/{{file}}:
  file.managed:
    - source: salt://copy-cert/{{file}}
    - user: root
    - group: root
    - mode: 600
    - makedirs: true

{% endfor %}
