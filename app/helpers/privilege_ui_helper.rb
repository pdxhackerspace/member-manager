# Renders an affordance only for accounts that hold the privilege behind it.
#
# This decides what a page OFFERS. It is never what PROTECTS the action: every gated
# affordance still needs its controller to refuse the request, because a hidden button is a
# courtesy and a URL is not. Both halves are asserted together by
# ActiveSupport::TestCase#assert_privilege_gates.
#
# Checks resolve through ApplicationController#can?, which asks the account being viewed as
# — so impersonating a member shows that member's buttons.
module PrivilegeUiHelper
  # Renders the block when the privilege is held, and nothing at all otherwise, so the
  # affordance is absent from the document rather than disabled or hidden with CSS.
  #
  #   <%= gate :'members.ban' do %>
  #     <li><button class="dropdown-item text-danger" ...>Ban…</button></li>
  #   <% end %>
  #
  #   <%= gate :'training.record', topic: @topic do %>…<% end %>
  #   <%= gate :'training.record', any_topic: true do %>…<% end %>
  #
  # For a privilege that drives more than a couple of regions in one template, hoist the
  # predicate to a local instead — see app/views/training_topics/edit.html.erb.
  def gate(privilege, topic: nil, any_topic: false, &)
    allowed = any_topic ? can_for_any_topic?(privilege) : can?(privilege, topic: topic)
    return unless allowed

    capture(&)
  end
end
