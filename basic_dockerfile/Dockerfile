FROM alpine:latest

# İleri seviye ekleme olmasaydı
# CMD ["echo", "Hello, Captain!"] 
# bu komut yeterliydi ancak Hello <adınız> yazmasını istediğim için

ENTRYPOINT ["sh", "-c", "echo \"Hello, ${1:-Captain}!\"", "--"]
