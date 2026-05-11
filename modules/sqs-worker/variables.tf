variable "name" {
  type        = string
  description = "Nome base para as filas (ex: kunlatek-eks)"
}

variable "visibility_timeout_seconds" {
  type        = number
  default     = 60
  description = "Tempo de visibilidade da mensagem — deve ser maior que o tempo de processamento"
}

variable "message_retention_seconds" {
  type        = number
  default     = 86400
  description = "Tempo de retenção das mensagens na fila principal (default: 1 dia)"
}

variable "dlq_message_retention_seconds" {
  type        = number
  default     = 1209600
  description = "Tempo de retenção das mensagens na DLQ (default: 14 dias)"
}

variable "max_receive_count" {
  type        = number
  default     = 3
  description = "Número de tentativas antes de mover para a DLQ"
}
