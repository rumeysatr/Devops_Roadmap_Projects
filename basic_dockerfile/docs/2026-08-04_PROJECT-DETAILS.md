Buradaki parçaların anlamı:

FROM: Oluşturacağın imajın hangi imajı temel alacağını söyler.

alpine: Küçük ve hafif bir Linux dağıtımıdır.

latest: Alpine imajının güncel etiketini kullanır.

ENTRYPOINT, konteyner her çalıştırıldığında yürütülecek ana komutu belirler.

sh -c, bir shell ifadesi çalıştırmayı sağlar.

${1:-Captain}, ilk argüman verilmişse onu; verilmemişse Captain değerini kullanır.

Sondaki --, shell içinde argümanların doğru konumlandırılmasını sağlar.

