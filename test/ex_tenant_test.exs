defmodule ExTenantTest do
  use ExUnit.Case

  alias ExTenant.Support.TenantRepo

  setup do
    {:ok, tenant} = TenantRepo.create_tenant("foo")
    {:ok, post} = TenantRepo.create_post("p1", "pb1", tenant.id)
    {:ok, comment} = TenantRepo.create_comment("c1", "cb1", post.id, tenant.id)

    {:ok, tenant: tenant, post: post, comment: comment}
  end

  describe "test the schema without using the macro code" do
    test "creates a tenant", %{tenant: tenant} do
      assert tenant.name == "foo"
    end

    test "creates a post in the tenant", %{tenant: tenant, post: post} do
      assert post.tenant_id == tenant.id
    end

    test "creates a comment on a post in the tenant", %{tenant: tenant, post: post, comment: comment} do
      assert comment.tenant_id == tenant.id
      assert comment.post_id == post.id
    end
  end
end
