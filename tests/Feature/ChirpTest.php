<?php

namespace Tests\Feature;

use App\Models\Chirp;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChirpTest extends TestCase
{
    use RefreshDatabase;

    /**
     * A basic feature test example.
     */
    public function test_example(): void
    {
        $response = $this->get('/');

        $response->assertStatus(200);
    }

    public function test_index_displays_chirps(): void
    {
        $user = User::factory()->create();
        Chirp::factory()->for($user)->create(['message' => 'Test Chirp']);

        $response = $this->actingAs($user)->get(route('chirps.index'));

        $response->assertStatus(200);
        $response->assertSee('Test Chirp');
    }

    public function test_store_creates_a_new_chirp(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)->post(route('chirps.store'), [
            'message' => 'New Chirp',
        ]);

        $response->assertRedirect(route('chirps.index'));
        $this->assertDatabaseHas('chirps', [
            'message' => 'New Chirp',
            'user_id' => $user->id,
        ]);
    }

    public function test_update_edits_an_existing_chirp(): void
    {
        $user = User::factory()->create();
        $chirp = Chirp::factory()->for($user)->create(['message' => 'Old Chirp']);

        $response = $this->actingAs($user)->put(route('chirps.update', $chirp), [
            'message' => 'Updated Chirp',
        ]);

        $response->assertRedirect(route('chirps.index'));
        $this->assertDatabaseHas('chirps', [
            'id' => $chirp->id,
            'message' => 'Updated Chirp',
        ]);
    }

    public function test_destroy_deletes_a_chirp(): void
    {
        $user = User::factory()->create();
        $chirp = Chirp::factory()->for($user)->create();

        $response = $this->actingAs($user)->delete(route('chirps.destroy', $chirp));

        $response->assertRedirect(route('chirps.index'));
        $this->assertDatabaseMissing('chirps', [
            'id' => $chirp->id,
        ]);
    }
}
