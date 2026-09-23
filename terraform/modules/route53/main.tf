resource "aws_route53_zone" "this" {
  name    = var.domain_name
  comment = var.comment

  vpc {
    vpc_id     = var.vpc_id
    vpc_region = var.vpc_region
  }

  tags = merge(var.tags, { Name = var.domain_name })
}

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = aws_route53_zone.this.zone_id
  name    = "${each.key}.${var.domain_name}"
  type    = var.record_type
  ttl     = var.ttl
  records = each.value
}
