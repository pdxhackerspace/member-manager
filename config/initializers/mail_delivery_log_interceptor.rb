# frozen_string_literal: true

# Delivery logging is handled by +ApplicationMailer+ delivery callbacks so failures can be
# recorded accurately. Keep this initializer as a compatibility placeholder for deployments
# that still autoload +MailDeliveryLogInterceptor+.
